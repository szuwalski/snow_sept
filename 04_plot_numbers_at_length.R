#==numbers at length visualizations
# Bring in observed survey numbers
library(ggplot2)
library(dplyr)
library(reshape)
library(ggridges)
library(gghighlight)
library(gridExtra)

library(gapminder)
library(gganimate)
library(transformr)


#=======================================
# EBS from the kodiak lab

kod_dat<-read.csv("data/survey/EBSCrab_Abundance_Biomass_female.csv",header=T,skip=7)
kod_dat_1<-filter(kod_dat,SEX=='FEMALE')
kod_dat_m<-kod_dat_1 %>%
  group_by(SURVEY_YEAR,SIZE_CLASS_MM) %>%
  summarize(abund=sum(ABUNDANCE))

p <- ggplot(dat=kod_dat_m) 
p <- p + geom_density_ridges(aes(x=SIZE_CLASS_MM, y=SURVEY_YEAR, height = abund,
                                 group = SURVEY_YEAR, 
                                 fill=stat(y),alpha=.9999),stat = "identity",scale=5,fill='#F8766D') +
  theme_bw() +
  theme(panel.border = element_blank(), panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(), axis.line = element_line(colour = "black")) +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 90)) +
  labs(x="Carapace width (mm)") +
  xlim(25,75)
png("plots/size_bins_comp_Kodiak_f.png",height=9,width=6,res=400,units='in')
print(p)
dev.off()

kod_dat<-read.csv("data/survey/EBSCrab_Abundance_Biomass_male.csv",header=T,skip=7)
kod_dat_1<-filter(kod_dat,SEX=='MALE')
kod_dat_m<-kod_dat_1 %>%
  group_by(SURVEY_YEAR,SIZE_CLASS_MM) %>%
  summarize(abund=sum(ABUNDANCE))

p <- ggplot(dat=kod_dat_m) 
p <- p + geom_density_ridges(aes(x=SIZE_CLASS_MM, y=SURVEY_YEAR, height = abund,
                                 group = SURVEY_YEAR, 
                                 fill=stat(y),alpha=.9999),stat = "identity",scale=5,fill='#619CFF') +
  theme_bw() +
  theme(panel.border = element_blank(), panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(), axis.line = element_line(colour = "black")) +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 90)) +
  labs(x="Carapace width (mm)") +
  xlim(25,135)

kod_dat_1<-filter(kod_dat,SEX=='MALE'&SIZE_CLASS_MM>100)
kod_dat_m<-kod_dat_1 %>%
  group_by(SURVEY_YEAR,SIZE_CLASS_MM) %>%
  summarize(abund=sum(ABUNDANCE))

g <- ggplot(dat=kod_dat_m) 
g <- g + geom_density_ridges(aes(x=SIZE_CLASS_MM, y=SURVEY_YEAR, height = abund,
                                 group = SURVEY_YEAR, 
                                 fill=stat(y),alpha=.9999),stat = "identity",scale=5,fill='#00BA38') +
  theme_bw() +
  theme(panel.border = element_blank(), panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(), axis.line = element_line(colour = "black")) +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 90)) +
  labs(x="Carapace width (mm)") +
  xlim(100,135)

png("plots/size_bins_comp_Kodiak_m.png",height=9,width=6,res=400,units='in')
(p|g)+plot_layout(widths=c(2.5,1))
dev.off()

#===============================
# survey recruitment compared to estimated recruitment
#===============================
kod_dat_m_rec<-filter(kod_dat,SIZE_CLASS_MM<55 & SEX == 'MALE' & SIZE_CLASS_MM>45) %>%
  group_by(SURVEY_YEAR) %>%
  summarize(rec=sum(ABUNDANCE))
plot(data=kod_dat_m_rec,rec~SURVEY_YEAR,type='l')
 
plotr<-data.frame(value=c(scale(kod_dat_m_rec$rec),
           scale(snowad.rep[[x]]$"estimated number of recruits male"),
           scale(M[[x]]$recruits[1,])),
           year=c(seq(1978,2017),seq(1982,2019),seq(1982,2019)),
           mod=c(rep('raw',40),rep('sq',38),rep('gmacs',38)))
p<-ggplot()+
  geom_line(data=plotr,aes(x=year,y=value,group=mod,col=mod),lwd=1.5)+
  theme_bw()+
  ylab(label="Scaled recruitment")
print(p)


