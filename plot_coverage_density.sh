#!/bin/bash

f=$1
Rscript -e 'require(tidyverse); c <- read.delim("'$f'"); ggplot(c, aes(x=coverage)) + geom_density() + scale_x_log10() + labs(title="'$f'"); ggsave("'$f'.density.png", height=5, width=8)'
