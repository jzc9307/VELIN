// VELIN's local speech worker: bounded binary PCM input / UTF-8 output over pipes.
// No sockets, credentials, downloads, audio files or cloud requests.
#include "whisper.h"
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <string>
#include <thread>
#include <vector>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif
static bool exact(char *bytes, size_t count) { return bool(std::cin.read(bytes, count)); }
static void reply(const std::string &text) {
    const uint32_t size = static_cast<uint32_t>(text.size());
    char header[4]; for (int i=0;i<4;i++)header[i]=char((size>>(8*i))&255);
    std::cout.write(header,4).write(text.data(),size).flush();
}
int main(int argc,char **argv) {
#ifdef _WIN32
    _setmode(_fileno(stdin), _O_BINARY); _setmode(_fileno(stdout), _O_BINARY);
#endif
    if(argc<2)return 2;
    whisper_log_set([](enum ggml_log_level,const char*,void*){},nullptr);
    auto options=whisper_context_default_params();
    auto *context=whisper_init_from_file_with_params(argv[1],options);
    if(!context)return 3;
    if(!whisper_is_multilingual(context)){whisper_free(context);return 4;}
    const std::string hint=argc>2?argv[2]:"";
    reply(""); // Ready only after model validation/loading.
    char header[4];
    while(exact(header,4)) {
        uint32_t count=0;for(int i=0;i<4;i++)count|=uint32_t(uint8_t(header[i]))<<(8*i);
        if(count<1600 || count>16000*20)break;
        std::vector<float> audio(count);
        if(!exact(reinterpret_cast<char*>(audio.data()),count*sizeof(float)))break;
        auto params=whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        params.n_threads=std::max(1u,std::min(4u,std::thread::hardware_concurrency()));
        params.translate=false;params.language="auto";params.no_context=true;
        params.print_realtime=false;params.print_progress=false;params.print_timestamps=false;params.print_special=false;
        params.initial_prompt=hint.c_str();params.suppress_nst=true;
        if(whisper_full(context,params,audio.data(),int(count))!=0){whisper_free(context);return 5;}
        std::string text;
        for(int i=0;i<whisper_full_n_segments(context);i++)text+=whisper_full_get_segment_text(context,i);
        if(text.size()>64000){whisper_free(context);return 6;}
        reply(text);
    }
    whisper_free(context);return 0;
}
