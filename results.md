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

Input               Function                       IPS           Min           Max          Mean           P99
Small XML           Nibble Xml Parser        1571.3233        0.5210        2.3104        0.6364        1.0128
Small XML           Splitter Xml Parser     24435.4212        0.0134        1.8319        0.0409        0.4537
Small XML           FFI Xml Parser          57915.7492        0.0109        1.3557        0.0172        0.0587
RSS XML             Nibble Xml Parser           1.9877      492.4236      523.7096      503.0826      523.7096
RSS XML             Splitter Xml Parser       286.8275        1.3565        6.9928        3.4864        5.9410
RSS XML             FFI Xml Parser             74.4078       10.7649       19.6065       13.4394       17.3714

Not benching Nibble Xml Parser on 20MB XML due to very long execution time and high memory usage.
benching set 20MB XML Splitter Xml Parser
benching set 20MB XML FFI Xml Parser

Input               Function                       IPS           Min           Max          Mean           P99
20MB XML            Splitter Xml Parser         0.1218     8035.5860     8295.8962     8204.7781     8295.8962
20MB XML            FFI Xml Parser              0.0540    18505.2516    18505.2516    18505.2516    18505.2516

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

Input               Function                       IPS           Min           Max          Mean           P99
Small XML           Nibble Xml Parser        2858.9662        0.2631        4.9039        0.3497        2.4830
Small XML           Splitter Xml Parser     19010.6962        0.0409        1.0833        0.0526        0.1294
Small XML           FFI Xml Parser            252.3183        2.0102       49.7116        3.9632       39.8011
RSS XML             Nibble Xml Parser           6.8022      138.2160      160.7954      147.0102      160.7954
RSS XML             Splitter Xml Parser       180.7588        4.3504       10.0672        5.5322        7.6727
RSS XML             FFI Xml Parser             83.1008        8.0660       39.3105       12.0335       37.5235

Not benching Nibble Xml Parser on 20MB XML due to very long execution time and high memory usage.
benching set 20MB XML Splitter Xml Parser
benching set 20MB XML FFI Xml Parser

Input               Function                       IPS           Min           Max          Mean           P99
20MB XML            Splitter Xml Parser         0.1209     7660.9426     9019.3744     8264.6108     9019.3744
20MB XML            FFI Xml Parser              0.0664    15047.9969    15047.9969    15047.9969    15047.9969

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
