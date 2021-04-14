#!/bin/bash

f=$1
Rscript -e 'require(tidyverse); c <- read.delim("'$f'"); ggplot(c, aes(x=coverage)) + geom_density() + scale_x_log10() + labs(title="'$f'"); ggsave("'$f'.density.xlog10.png", height=5, width=8)'
Rscript -e 'require(tidyverse); c <- read.delim("'$f'"); ggplot(c, aes(x=coverage)) + geom_density() + xlim(0,200) + labs(title="'$f'"); ggsave("'$f'.density.lt200.png", height=5, width=8)'
Rscript -e 'require(tidyverse); c <- read.delim("'$f'"); ggplot(c, aes(x=coverage)) + geom_histogram(binwidth=1) + xlim(0,200) + labs(title="'$f'"); ggsave("'$f'.hist.lt200.png", height=5, width=8)'
