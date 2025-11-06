# Results

## The benchmark

All the benchmarking has been done using [gleam_benchy](https://github.com/schurhammer/gleamy_bench).
It seems to be a decent Gleam benchmarking library, even though not super advanced. But I don't need
anything complicated so it fits my needs. All that will be benched is execution time. 

I chose to compare 2 parsers of mine: one written using nibble and one using splitter with an FFI reference.
The reference for the Erlang target is xmerl and the reference for the JavaScript target jsdom.
I also chose different XML document to bench those parsers against. The first is a small trivial XML string.
The second is a "medium-sized" RSS XML taken from phys.org (which is the kind of document I want to parse).
The third is a "large" XML taken from [this site](https://aiweb.cs.washington.edu/research/projects/xmltk/xmldata/). It is about 20MB in size and has a max depth of 8.

## The setup

I ran this benchmark on a Windows 11 computer with an Intel i7 CPU and 32GB of RAM.

## Erlang target

### Benchmark results

benching set Small XML Nibble Xml Parser
benching set Small XML Splitter Xml Parser
benching set Small XML FFI Xml Parser
benching set RSS XML Nibble Xml Parser
benching set RSS XML Splitter Xml Parser
benching set RSS XML FFI Xml Parser

Input               Function                       IPS          Mean            SD           Min           Max           P99
Small XML           Nibble Xml Parser        1621.5860        0.6166        0.0598        0.5202        1.3497        0.8220
Small XML           Splitter Xml Parser     25711.5187        0.0388        0.0757        0.0134        2.5307        0.4296
Small XML           FFI Xml Parser          61161.1047        0.0163        0.0110        0.0110        0.6093        0.0522
RSS XML             Nibble Xml Parser           2.0644      484.3904        6.0017      477.0457      493.7076      493.7076
RSS XML             Splitter Xml Parser       302.1760        3.3093        0.7497        2.4544        5.9974        5.2471
RSS XML             FFI Xml Parser             74.8305       13.3635        0.5270       12.3682       16.3330       14.8474

Not benching Nibble Xml Parser on 20MB XML due to very long execution time and high memory usage.
benching set 20MB XML Splitter Xml Parser
benching set 20MB XML FFI Xml Parser

Input               Function                       IPS           Min           Max          Mean           P99
20MB XML            Splitter Xml Parser         0.1296     7535.8357     7831.2075     7715.1691     7831.2075
20MB XML            FFI Xml Parser              0.0528    18911.3905    18911.3905    18911.3905    18911.3905

### Analysis

The most obvious observation we can make is that the Nibble parser does not perform as well as the other two parsers, especially as the size of the input grows.
I have been told that nibble isn't optimized and has a lot of overhead, so I kinda expected this result.
I have been surprised by the performance of the splitter parser, especially compared to the FFI parser.
I expected the FFI parser to be very optimized and as such to outperform the splitter parser.
However, the result shows that the splitter parser can be 2.2 (20MB XML) to 3.8 (RSS XML) times faster than the FFI parser and 144 (RSS XML) times faster than the nibble parser.
It is still 2.4 times slower than the FFI parser on the small XML input, but we may be within a margin of error there.

## JavaScript target

### Benchmark results

benching set Small XML Nibble Xml Parser
benching set Small XML Splitter Xml Parser
benching set Small XML FFI Xml Parser
benching set RSS XML Nibble Xml Parser
benching set RSS XML Splitter Xml Parser
benching set RSS XML FFI Xml Parser

Input               Function                       IPS          Mean            SD           Min           Max           P99
Small XML           Nibble Xml Parser        2962.1175        0.3375        0.1985        0.2614        2.4809        1.5666
Small XML           Splitter Xml Parser     19289.0837        0.0518        0.0371        0.0400        2.2642        0.1230
Small XML           FFI Xml Parser            277.0603        3.6093        4.9692        1.9326       38.6214       33.3262
RSS XML             Nibble Xml Parser           6.2610      159.7168       37.1099      126.2318      243.1317      243.1317
RSS XML             Splitter Xml Parser       185.6392        5.3867        2.0135        3.8836       18.4995       14.0524
RSS XML             FFI Xml Parser             92.3344       10.8301        5.1439        7.6413       28.0219       25.9219

Not benching Nibble Xml Parser on 20MB XML due to very long execution time and high memory usage.
benching set 20MB XML Splitter Xml Parser
benching set 20MB XML FFI Xml Parser

Input               Function                       IPS           Min           Max          Mean           P99
20MB XML            Splitter Xml Parser         0.1380     7024.2156     7462.3651     7243.2438     7462.3651
20MB XML            FFI Xml Parser              0.0656    15236.0095    15236.0095    15236.0095    15236.0095

### Analysis

Again, the Nibble parser performs poorly compared to the other two parsers, especially as the input size increases.
Here I expected the FFI parser to perform worse than the FFI parser on Erlang as jsdom isn't the most optimized XML parser out there.
However, It will serve as a reference point for this analysis.
The splitter parser again outperforms the FFI parser, being about 2 times faster on both the RSS XML and 20MB XML inputs.
On the small XML input, the FFI parser performs very poorly, probably due to overhead in the jsdom library.
The splitter parser also performed 6.6 (Small XML) to 26.6 (RSS XML) times better than the nibble parser.
I guess the difference is even more drastic on larger files.

### Notes

I had to run the JavaScript benchmarks with the NODE_OPTIONS="--max-old-space-size=8192" environment variable to avoid out-of-memory errors on the 20MB XML input for the FFI parser.

## Comparison between targets

Overall, the results seem quite similar, with the splitter beating the FFI parser, but with both within the same order of magnitude.
The nibble parser is the slowest for documents larger than trivial data by at least one order of magnitude.
Also, the performance between targets is comparable with performance for each input & parser combination always within the same order of magnitude.

## Conclusions

I am very satisifed by these results. I didn't expect the splitter parsers to perform so well, especially since I introduced some overhead
with the concept of Parsers. I still have to keep in mind that my parsers aren't exactly XML parsers as I left out parts of the specification
and have not been very strict on some points. If I were to implement those, my splitter parser's performance may decrease and be comparable to
that of the FFI versions.

I should also test memory usage, but I currently don't know how to do this, so this will be a problem for another time.
