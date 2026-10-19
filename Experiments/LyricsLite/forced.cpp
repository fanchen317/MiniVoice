#include "whisper.h"
#include "json.hpp"
#include <algorithm>
#include <cmath>
#include <fstream>
#include <iostream>
#include <limits>
#include <vector>
using json=nlohmann::json;
struct Forced {
    std::vector<whisper_token> tokens;
    std::vector<double> logProb;
};
// Measure acoustic likelihood before constraining decoding to the supplied lyrics.
static void force_tokens(whisper_context *ctx, whisper_state *, const whisper_token_data *, int count,
                         float *logits, void *opaque) {
    auto &s=*static_cast<Forced *>(opaque);
    auto wanted=count<int(s.tokens.size()) ? s.tokens[count] : whisper_token_eot(ctx);
    int vocab=whisper_n_vocab(ctx);
    if(count<int(s.tokens.size())) {
        float peak=*std::max_element(logits,logits+vocab);
        double total=0;
        for(int k=0;k<vocab;k++) total+=std::exp(double(logits[k]-peak));
        if(int(s.logProb.size())<=count) s.logProb.resize(count+1,-100);
        s.logProb[count]=double(logits[wanted]-peak)-std::log(total);
    }
    std::fill(logits,logits+vocab,-std::numeric_limits<float>::infinity());
    logits[wanted]=0;
}
int main(int argc,char **argv) {
    if(argc!=3) { std::cerr<<"Usage: lyrics-force request.json output.json\n";return 2; }
    try {
        json req;std::ifstream(argv[1])>>req;
        std::ifstream input(req.at("pcmPath").get<std::string>(),std::ios::binary|std::ios::ate);
        if(!input) throw std::runtime_error("Missing PCM input");
        size_t bytes=input.tellg();input.seekg(0);
        std::vector<float> pcm(bytes/sizeof(float));input.read(reinterpret_cast<char *>(pcm.data()),bytes);
        auto contextParams=whisper_context_default_params();
        contextParams.use_gpu=true;contextParams.flash_attn=false;
        contextParams.dtw_token_timestamps=true;
        contextParams.dtw_aheads_preset=WHISPER_AHEADS_SMALL;
        auto model=req.at("modelPath").get<std::string>();
        auto *ctx=whisper_init_from_file_with_params(model.c_str(),contextParams);
        if(!ctx) throw std::runtime_error("Cannot load model");
        json output=json::array();
        auto language=req.at("language").get<std::string>();
        for(auto &window:req.at("windows")) {
            double left=window.at("start"),right=window.at("end");
            if(left<0 || right<=left || right-left>29.5 || right*16000>pcm.size()+16)
                throw std::runtime_error("Invalid acoustic window");
            Forced forced;
            std::vector<int> lineForToken;
            auto lines=window.at("lines").get<std::vector<std::string>>();
            for(size_t i=0;i<lines.size();i++) {
                std::string text=" "+lines[i];
                int n=whisper_token_count(ctx,text.c_str());
                std::vector<whisper_token> ids(n);
                if(whisper_tokenize(ctx,text.c_str(),ids.data(),n)!=n) throw std::runtime_error("Tokenization failed");
                for(auto id:ids) { forced.tokens.push_back(id);lineForToken.push_back(i); }
            }
            if(forced.tokens.size()>200) throw std::runtime_error("Window text too long");
            auto params=whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
            params.n_threads=4;params.language=language.c_str();
            params.no_context=true;params.no_timestamps=true;params.single_segment=true;
            params.token_timestamps=true;params.print_progress=false;params.print_realtime=false;
            params.print_timestamps=false;params.suppress_blank=false;
            params.temperature=0;params.temperature_inc=0;params.greedy.best_of=1;
            params.entropy_thold=1e9;params.logprob_thold=-1e9;params.no_speech_thold=1;
            params.logits_filter_callback=force_tokens;params.logits_filter_callback_user_data=&forced;
            int begin=std::min(pcm.size(),size_t(left*16000));
            int size=std::min(pcm.size()-begin,size_t((right-left)*16000));
            double energy=0;
            for(int k=begin;k<begin+size;k++) energy+=double(pcm[k])*pcm[k];
            if(energy/std::max(1,size)<1e-10) {
                for(size_t line=0;line<lines.size();line++) output.push_back({{"index",int(window.at("firstIndex"))+int(line)},{"start",nullptr},{"end",nullptr},{"confidence",0}});
                continue;
            }
            if(whisper_full(ctx,params,pcm.data()+begin,size)!=0) throw std::runtime_error("Forced decoding failed");
            std::vector<double> starts(lines.size(),-1),ends(lines.size(),-1),sums(lines.size(),0);
            std::vector<int> counts(lines.size(),0);
            size_t pos=0;
            for(int segment=0;segment<whisper_full_n_segments(ctx);segment++) {
                for(int k=0;k<whisper_full_n_tokens(ctx,segment);k++) {
                    auto data=whisper_full_get_token_data(ctx,segment,k);
                    if(data.id>=whisper_token_eot(ctx)) continue;
                    if(pos>=forced.tokens.size() || data.id!=forced.tokens[pos]) throw std::runtime_error("Reference token sequence changed");
                    int line=lineForToken[pos];
                    std::string text=whisper_token_to_str(ctx,data.id);
                    bool nonspace=std::any_of(text.begin(),text.end(),[](unsigned char c){ return !std::isspace(c); });
                    if(nonspace && data.t_dtw>=0) {
                        double time=left+data.t_dtw/100.0;
                        if(starts[line]<0) starts[line]=time;
                        ends[line]=std::max(ends[line],time);
                        if(pos<forced.logProb.size()) { sums[line]+=forced.logProb[pos];counts[line]++; }
                    }
                    pos++;
                }
            }
            for(size_t line=0;line<lines.size();line++) {
                double confidence=counts[line] ? std::exp(sums[line]/counts[line]) : 0;
                // Low-likelihood forced text must not be treated as an actual match.
                bool valid=starts[line]>=left && ends[line]>starts[line] && confidence>=0.05;
                output.push_back({{"index",int(window.at("firstIndex"))+int(line)},
                    {"start",valid?json(starts[line]):json(nullptr)},
                    {"end",valid?json(std::min(right,ends[line]+0.1)):json(nullptr)},
                    {"confidence",confidence}});
            }
        }
        whisper_free(ctx);
        std::ofstream(argv[2])<<output.dump(2);
    } catch(const std::exception &e) { std::cerr<<e.what()<<"\n";return 1; }
}
