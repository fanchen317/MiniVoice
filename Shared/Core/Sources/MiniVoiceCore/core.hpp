#pragma once
#include <string>
#include <vector>
#include <map>
#include <cstdint>
namespace mv {
struct Word {int64_t ms,endMs;std::string text;};
struct Line {int64_t ms;std::string text,translation;std::vector<Word> words;};
struct Anchor {int index,offset;};
std::vector<Line> parseLyrics(const std::string &raw);
double characters(const Line &line,int64_t next,int64_t duration,int64_t position);
std::string artistKey(const std::string &value);
std::string canonicalArtist(const std::string &value,const std::map<std::string,std::string> &aliases);
bool reusable(const std::string &previous,const std::string &current);
Anchor restoreAnchor(const std::vector<std::string> &items,const std::string &identity,int fallback,int offset);
bool canSnapshot(const std::vector<std::string> &rendered,const std::vector<std::string> &current,int first,int last);
std::string execute(const std::string &request);
}
