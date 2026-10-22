#include "core.hpp"
#include "include/minivoice_core.h"
#include "vendor/json.hpp"
#include "vendor/utf8proc.h"
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <regex>
#include <set>
#include <stdexcept>
#include <sstream>
using json=nlohmann::json;
namespace mv {
namespace {
bool space(int32_t cp){auto category=utf8proc_category(cp);return cp==32||(cp>=9&&cp<=13)||category==UTF8PROC_CATEGORY_ZS||category==UTF8PROC_CATEGORY_ZL||category==UTF8PROC_CATEGORY_ZP;}
std::string normalize(const std::string &value,bool folded,bool collapse){
    if(value.find('\0')!=std::string::npos)throw std::invalid_argument("NUL is not valid text");
    utf8proc_uint8_t *mapped=nullptr;
    auto flags=static_cast<utf8proc_option_t>(UTF8PROC_STABLE|UTF8PROC_COMPOSE|UTF8PROC_COMPAT|(folded?UTF8PROC_CASEFOLD:0));
    auto length=utf8proc_map(reinterpret_cast<const utf8proc_uint8_t*>(value.data()),value.size(),&mapped,flags);
    if(length<0)throw std::invalid_argument("Invalid UTF-8");
    std::string result;bool pending=false;
    for(ptrdiff_t at=0;at<length;){int32_t cp;auto step=utf8proc_iterate(mapped+at,length-at,&cp);if(step<=0){free(mapped);throw std::invalid_argument("Invalid UTF-8");}
        bool blank=space(cp);if(collapse&&blank){if(!result.empty())pending=true;}else{if(pending){result+=' ';pending=false;}result.append(reinterpret_cast<char*>(mapped+at),step);}at+=step;
    }free(mapped);return result;
}
std::string trim(std::string value){auto first=value.find_first_not_of(" \t\r\n");if(first==std::string::npos)return "";return value.substr(first,value.find_last_not_of(" \t\r\n")-first+1);}
int64_t stamp(const std::smatch &match){auto fraction=match[3].str()+"000";return std::stoll(match[1])*60000+std::stoll(match[2])*1000+std::stoll(fraction.substr(0,3));}
size_t utf16Length(const std::string &value){size_t count=0;for(size_t at=0;at<value.size();){int32_t cp;auto step=utf8proc_iterate(reinterpret_cast<const uint8_t*>(value.data()+at),value.size()-at,&cp);if(step<=0)throw std::invalid_argument("Invalid UTF-8");count+=cp>0xffff?2:1;at+=step;}return count;}
double progress(int64_t at,int64_t start,int64_t end){return std::clamp(double(at-start)/std::max<int64_t>(1,end-start),0.0,1.0);}
json lineJSON(const Line &line){json words=json::array();for(const auto &word:line.words)words.push_back({{"ms",word.ms},{"endMs",word.endMs},{"text",word.text}});return {{"ms",line.ms},{"text",line.text},{"translation",line.translation},{"words",words}};}
Line decodeLine(const json &value){Line result{value.value("ms",int64_t(-1)),value.value("text",std::string()),value.value("translation",std::string()),{}};for(const auto &word:value.value("words",json::array()))result.words.push_back({word.at("ms"),word.value("endMs",int64_t(-1)),word.at("text")});return result;}
}
std::string artistKey(const std::string &value){return normalize(value,true,true);}
std::string canonicalArtist(const std::string &value,const std::map<std::string,std::string> &aliases){std::string current=normalize(value,false,true);std::set<std::string> seen;while(seen.insert(artistKey(current)).second){auto found=aliases.find(artistKey(current));if(found==aliases.end()||trim(found->second).empty())break;current=normalize(found->second,false,true);}return current;}
bool reusable(const std::string &previous,const std::string &current){if(previous!=current)return false;static const std::regex version("([0-9]+):([0-9]+)");std::smatch match;if(!std::regex_match(current,match,version))return false;try{return std::stoll(match[1])>0&&std::stoll(match[2])>0;}catch(...){return false;}}
Anchor restoreAnchor(const std::vector<std::string> &items,const std::string &identity,int fallback,int offset){if(items.empty())return {-1,0};auto found=std::find(items.begin(),items.end(),identity);return {found==items.end()?std::clamp(fallback,0,int(items.size()-1)):int(found-items.begin()),offset};}
bool canSnapshot(const std::vector<std::string> &rendered,const std::vector<std::string> &current,int first,int last){return first>=0&&last>=first&&last<int(current.size())&&rendered==current;}
std::vector<Line> parseLyrics(const std::string &raw){
    if(raw.size()>1024*1024)throw std::invalid_argument("Lyrics exceed 1 MiB");
    static const std::regex stamps(R"(\[([0-9]{1,3}):([0-9]{2})(?:[.:]([0-9]{1,3}))?\])");
    static const std::regex markers(R"(<([0-9]{1,3}):([0-9]{2})(?:[.:]([0-9]{1,3}))?>)");
    static const std::regex yrc(R"(^\[([0-9]{1,10}),([0-9]{1,10})\](.*)$)");
    static const std::regex ywords(R"(\(([0-9]{1,10}),([0-9]{1,10}),[0-9]+\))");
    static const std::regex offsetPattern(R"(^\s*\[offset:([+-]?[0-9]{1,9})\]\s*$)",std::regex::ECMAScript|std::regex::icase|std::regex::multiline);
    std::string source=raw;for(const std::string separator:{"\xef\xbb\xbf","\xe2\x80\xa8","\xe2\x80\xa9"}){size_t at;while((at=source.find(separator))!=std::string::npos)source.replace(at,separator.size(),separator=="\xef\xbb\xbf"?"":"\n");}
    std::replace(source.begin(),source.end(),'\r','\n');std::smatch offsetMatch;int64_t offset=std::regex_search(source,offsetMatch,offsetPattern)?std::stoll(offsetMatch[1]):0;
    std::vector<Line> timed,plain;std::istringstream stream(source);std::string row;
    while(std::getline(stream,row)){
        std::smatch header;std::string clean=trim(row);
        if(std::regex_match(clean,header,yrc)){
            std::string body=header[3];std::vector<Word> words;int64_t start=-1,end=-1;size_t from=0;
            for(std::sregex_iterator i(body.begin(),body.end(),ywords),last;i!=last;++i){auto part=body.substr(from,i->position()-from);if(start>=0&&!part.empty())words.push_back({std::max<int64_t>(0,start+offset),std::max<int64_t>(0,end+offset),part});start=std::stoll((*i)[1]);end=start+std::stoll((*i)[2]);from=i->position()+i->length();}
            auto tail=body.substr(from);if(start>=0&&!tail.empty())words.push_back({std::max<int64_t>(0,start+offset),std::max<int64_t>(0,end+offset),tail});auto text=trim(std::regex_replace(body,ywords,""));if(!text.empty())timed.push_back({std::max<int64_t>(0,std::stoll(header[1])+offset),text,"",words});continue;
        }
        std::vector<int64_t> times;for(std::sregex_iterator i(row.begin(),row.end(),stamps),last;i!=last;++i)if(std::stoi((*i)[2])<60)times.push_back(stamp(*i));
        std::string body=std::regex_replace(row,stamps,"");std::smatch firstWord;if(times.empty()&&std::regex_search(body,firstWord,markers)&&std::stoi(firstWord[2])<60)times.push_back(stamp(firstWord));
        std::vector<Word> words;int64_t previous=-1;size_t from=0;
        for(std::sregex_iterator i(body.begin(),body.end(),markers),last;i!=last;++i){auto part=body.substr(from,i->position()-from);auto time=stamp(*i);if(previous>=0&&!part.empty())words.push_back({std::max<int64_t>(0,previous+offset),std::max<int64_t>(0,time+offset),part});previous=time;from=i->position()+i->length();}
        auto tail=body.substr(from);if(previous>=0&&!tail.empty())words.push_back({std::max<int64_t>(0,previous+offset),-1,tail});auto text=trim(std::regex_replace(body,markers,""));
        if(times.empty()&&!text.empty()&&!clean.empty()&&clean[0]!='['&&clean[0]!='<')plain.push_back({-1,text,"",{}});
        if(!text.empty())for(auto timestamp:times){auto shifted=words;for(auto &word:shifted){word.ms=std::max<int64_t>(0,word.ms+timestamp-times[0]);if(word.endMs>=0)word.endMs=std::max<int64_t>(0,word.endMs+timestamp-times[0]);}timed.push_back({std::max<int64_t>(0,timestamp+offset),text,"",shifted});}
    }
    std::stable_sort(timed.begin(),timed.end(),[](const Line &a,const Line &b){return a.ms<b.ms;});std::vector<Line> merged;
    for(auto &line:timed){if(!merged.empty()&&merged.back().ms==line.ms){auto &primary=merged.back();if(primary.text==line.text){if(primary.words.empty()&&!line.words.empty())primary.words=line.words;continue;}if(primary.words.empty()&&!line.words.empty()){line.translation=primary.text+(primary.translation.empty()?"":"\n"+primary.translation);primary=line;}else if(primary.translation!=line.text)primary.translation+=(primary.translation.empty()?"":"\n")+line.text;}else merged.push_back(line);}
    return merged.empty()?plain:merged;
}
double characters(const Line &line,int64_t next,int64_t duration,int64_t position){
    auto count=utf16Length(line.text);if(line.ms<0)return count;int64_t end=next>line.ms?next:duration>line.ms?duration:line.ms+4000;
    if(line.words.empty())return count*progress(position,line.ms,std::min(end,line.ms+12000));
    size_t cursor=0;double visible=0;for(size_t i=0;i<line.words.size();++i){const auto &word=line.words[i];auto start=line.text.find(word.text,cursor);if(start==std::string::npos)continue;auto finish=word.endMs>word.ms?word.endMs:i+1<line.words.size()?line.words[i+1].ms:end;if(position<word.ms)break;visible=utf16Length(line.text.substr(0,start))+utf16Length(word.text)*progress(position,word.ms,finish);cursor=start+word.text.size();}return std::min<double>(count,visible);
}
std::string execute(const std::string &request){
    try{
        if(request.size()>4*1024*1024)throw std::invalid_argument("Request exceeds 4 MiB");
        const auto input=json::parse(request);if(input.value("version",1)!=1)throw std::invalid_argument("Unsupported contract version");std::string op=input.at("op");json value;
        if(op=="lyrics.parse"){value=json::array();for(const auto &line:parseLyrics(input.value("raw",std::string())))value.push_back(lineJSON(line));}
        else if(op=="lyrics.sweep")value=characters(decodeLine(input.at("line")),input.value("next",int64_t(0)),input.value("duration",int64_t(0)),input.value("position",int64_t(0)));
        else if(op=="artist.key")value=artistKey(input.value("value",std::string()));
        else if(op=="artist.canonical")value=canonicalArtist(input.value("value",std::string()),input.value("aliases",std::map<std::string,std::string>()));
        else if(op=="scan.reusable")value=reusable(input.value("previous",std::string()),input.value("current",std::string()));
        else if(op=="page.restore"){auto anchor=restoreAnchor(input.at("items").get<std::vector<std::string>>(),input.value("identity",std::string()),input.value("index",0),input.value("offset",0));value={{"index",anchor.index},{"offset",anchor.offset}};}
        else if(op=="state.reduce"){
            value=input.value("state",json::object());auto action=input.at("action");std::string type=action.at("type");
            if(type=="navigate"){value["section"]=action.at("section");value["group"]=action.value("group",std::string());}
            else if(type=="page"){auto key=action.at("key").get<std::string>();json page=value.value("pages",json::object()).value(key,json::object());page.merge_patch(action.at("patch"));value["pages"][key]=page;}
            else if(type=="sort")value["sorting"][action.at("category").get<std::string>()]=action.at("value");
            else throw std::invalid_argument("Unknown state action");value["version"]=1;
        }
        else if(op=="library.filter"){
            value=json::array();auto query=artistKey(input.value("query",std::string()));for(const auto &song:input.at("songs")){auto match=artistKey(song.value("title",std::string())+" "+song.value("artist",std::string())+" "+song.value("album",std::string()));if(query.empty()||match.find(query)!=std::string::npos)value.push_back(song);}
        }
        else throw std::invalid_argument("Unknown core operation");return json({{"version",1},{"ok",true},{"value",value}}).dump();
    }catch(const std::exception &error){return json({{"version",1},{"ok",false},{"error",error.what()}}).dump();}
}
}
extern "C" char *mv_core_execute(const char *request){try{auto result=mv::execute(request?request:"");auto *output=static_cast<char*>(malloc(result.size()+1));if(output)memcpy(output,result.c_str(),result.size()+1);return output;}catch(...){return nullptr;}}
extern "C" void mv_core_free(char *response){free(response);}
extern "C" int mv_core_contract_version(void){return 1;}
