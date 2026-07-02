#==tier 4 application to snow crab
library(dplyr)
library(reshape2)
library(ggplot2)
library(png)
library(grid)
library(patchwork)
library(crabpack)
library(dplyr)
library(ggplot2)
library(reshape2)
library(ggridges)
library(tidyr)

#==set up with crab pack
#==tier 4 like BBRKC
#===do it with both MMB and 95mm
#==plot the preferred males on each time series of the tier 4 OFL

## Pull specimen data
specimen_data <- crabpack::get_specimen_data(species = "SNOW",
                                             region = "EBS",
                                             years = c(1982:2025),
                                             channel = 'API')


male_snow_ind <- crabpack::calc_bioabund(crab_data = specimen_data,
                                         species = "SNOW",
                                         region = "EBS",
                                         crab_category = c("all_categories"))



com_male<-filter(male_snow_ind,CATEGORY=="preferred_male"&YEAR >1981)$BIOMASS_MT
lg_male<-filter(male_snow_ind,CATEGORY=="large_male"&YEAR >1981)$BIOMASS_MT
surv_yr<-unique(male_snow_ind$YEAR)
nat_m<-0.27
mmb <- read.table("data/derived/index_mmb.txt")

#=decrement survey by 1/2 year M
com_male_fish<-com_male*exp(-nat_m/2)/1000
lg_male_fish<-lg_male*exp(-nat_m/2)/1000
mmb_male_fish<-mmb*exp(-nat_m/2)/1000

#==calculate BMSY as average
cut_bio<-1982
com_male_bmsy<-mean(com_male_fish[which(surv_yr==cut_bio):length(com_male_fish)])
lg_male_bmsy<-mean(lg_male_fish[which(surv_yr==cut_bio):length(lg_male_fish)])
mmb_male_bmsy<-mean(mmb_male_fish[which(surv_yr==cut_bio):length(mmb_male_fish)])

#==calculate status
com_male_stat<-com_male_fish/com_male_bmsy
lg_male_stat<-lg_male_fish/lg_male_bmsy
mmb_male_stat<-mmb_male_fish/mmb_male_bmsy

plot(com_male_stat~c(seq(1982,2019),seq(2021,2025)),type='b',ylab='Status',ylim=c(0,4.2),las=1,
     xlab="Year")
abline(h=0.25,lty=2,col=2)
abline(h=0.5,lty=2,col=3)

plot(lg_male_stat~c(seq(1982,2019),seq(2021,2025)),type='b',ylab='Status',ylim=c(0,4.2),las=1,
     xlab="Year")
abline(h=0.25,lty=2,col=2)
abline(h=0.5,lty=2,col=3)

#==calculate FOFL from status and natural mortality
fofl_com_male<-rep(nat_m,length(com_male_fish))
fofl_lg_male<-rep(nat_m,length(lg_male_fish))

beta<-0.25
alpha<-0.1
for(x in 1:length(com_male_stat))
{
#==commercial males
 if(com_male_stat[x]<1)
 {
   fofl_com_male[x] <- 0
   if(com_male_stat[x]>beta)
    fofl_com_male[x] <- nat_m * (com_male_stat[x]-alpha)/(1-alpha)
 }
  

#==large males
if(lg_male_stat[x]<1)
{
  fofl_lg_male[x] <- 0
  if(lg_male_stat[x]>beta)
    fofl_lg_male[x] <- nat_m * (lg_male_stat[x]-alpha)/(1-alpha)
}
}

#==show SSC version

#==calculate OFL based off of MMB
OFL_com_mmb<-com_male_fish*(1-exp(-fofl_com_male))
OFL_lg_mmb<-lg_male_fish*(1-exp(-fofl_lg_male))

order(com_male_fish)

#==do SSC's version
#==read in the MMB
mmb <- read.table("data/derived/index_mmb.txt")

OFL_ssc<-com_male/1000*(1-exp(-nat_m))
OFL_mmb<-mmb*(1-exp(-nat_m))

c(mmb,com_male_fish,lg_male_fish)
plot_ofl<-data.frame(biomass=unlist(c(mmb,com_male_fish,lg_male_fish)),
           ofl=unlist(c(OFL_mmb,OFL_com_mmb,OFL_lg_mmb)),
           year=rep(c(seq(1982,2019),seq(2021,2025)),3),
           currency=c(rep("Morphometric",length(com_male_fish)),
                      rep(">101 mm",length(com_male_fish)),
                      rep(">95 mm",length(com_male_fish))))

blup<-filter(plot_ofl,currency==">101 mm")
blup$biomass[blup$biomass>125]<-125
cha<-ggplot(plot_ofl)+
  geom_line(data=plot_ofl,aes(x=year,y=ofl,col=currency),lwd=1.2)+
  geom_line(data=blup,aes(y=biomass,x=year),lwd=1.2,lty=2)+
  theme_bw()+theme(legend.position=c(.8,.8))+
  ylab("OFL (1,000 t)")+ylim(0,125)

sha<-ggplot(plot_ofl)+
  geom_line(aes(x=year,y=biomass,col=currency),lwd=1.5)+
  geom_line(aes(x=year,y=ofl,col=currency),lwd=1)+
  theme_bw()+facet_wrap(~currency,ncol=1)+theme(legend.position="")+
  ylab("Biomass/OFL (1,000 t)")

png('plots/tier_4.png',height=7,width=7,res=350,units='in')
cha + sha + plot_layout(ncol=2,widths=c(4,1))
dev.off()



ret_cat<-read.csv("data/new_catch/retained_catch.csv")
colnames(ret_cat)[1]<-'year'
compit<-merge(plot_ofl,ret_cat,by='year')
compit$tot_retained_wt<-compit$tot_retained_wt/1000
compit$exp_rate<-(compit$tot_retained_wt)/compit$biomass

#==the time the large males rebuild (2000-2011), the 'exploitation rate'
#==on large males was about 0.25-0.3
#==then it ratcheted up and
png('plots/obs_exploit_rate.png',height=7,width=7,res=350,units='in')
ggplot()+
  geom_point(data=compit,aes(x=year,y=exp_rate,col=currency))+
  geom_line(data=filter(compit,year<2020),aes(x=year,y=exp_rate,col=currency),lwd=1.2)+
  geom_line(data=filter(compit,year>2020),aes(x=year,y=exp_rate,col=currency),lwd=1.2)+
  theme_bw()+theme(legend.position=c(.8,.8))+
  ylab("Retained catch / Biomass")
dev.off()  

write.csv(compit[,c(1,2,4,11)],'obs_exp_dat.csv')

#==================================
# REMA APPLICATION
#==================================
#devtools::install_github("afsc-assessments/rema", dependencies = TRUE, build_vignettes = FALSE)
library(rema)

mmb_dat<-read.csv("data/derived/index_mmb.txt",header=F)
mmb_cv<-read.csv("data/derived/index_female_biomass_male_cv.csv")
com_male_cv<-filter(male_snow_ind,CATEGORY=="preferred_male"&YEAR >1981)$BIOMASS_MT_CV
lg_male_cv<-filter(male_snow_ind,CATEGORY=="large_male"&YEAR >1981)$BIOMASS_MT_CV
dats<-data.frame(morph=mmb_dat,morph_cv=mmb_cv[,4],large=lg_male,large_cv=lg_male_cv,
                 pref=com_male,pref_cv=com_male_cv,year=surv_yr)

keep_status<-NULL
keep_fofl<-NULL
keep_rema<-NULL
keep_bmsy<-NULL
#==============================
# morphometrically mature
morph<-data.frame(biomass=mmb_dat,cv=mmb_cv[,4],year=surv_yr,strata='EBS')
colnames(morph)<-c("biomass","cv","year","strata")
input<-prepare_rema_input(model_name='morph',biomass_dat=morph)
m<-fit_rema(input)
output<-tidy_rema(rema_model=m)
#==basic OFL
OFL_m<- round(.27*output$total_predicted_biomass[nrow(output$total_predicted_biomass),]$pred,2)

#==HCR OFL
#===calc BMSY and status
#===APPLY NATURAL MORTALITY OR NOT???
term_mmb<-output$total_predicted_biomass[nrow(output$total_predicted_biomass),]$pred
mmb_bmsy<-mean(filter(output$total_predicted_biomass,year<2025)$pred)
mmb_status<-term_mmb/mmb_bmsy
tmp<-data.frame(Year=output$total_predicted_biomass$year,
           rema_pred=output$total_predicted_biomass$pred,
           size='morphometric')
keep_rema<-rbind(keep_rema,tmp)

#===find FOFL
beta<-0.25
alpha<-0.1
nat_m<-0.27
fofl_mmb_male<-nat_m
if(mmb_status<1)
  {
    fofl_mmb_male <- 0
    if(mmb_status>beta)
      fofl_mmb_male <- nat_m * (mmb_status-alpha)/(1-alpha)
  }
keep_status<-c(keep_status,mmb_status)
keep_fofl<-c(keep_fofl,fofl_mmb_male)
keep_bmsy<-c(keep_bmsy,mmb_bmsy)

OFL_m<- round(fofl_mmb_male*term_mmb,2)
OFL_dana<-nat_m*term_mmb*mmb_status

#===apply to MMB to get OFL
morph_plot<-plot_rema(tidy_rema=output)$biomass_by_strata+theme_bw()+ylab("Biomass 1,000 t")+
  annotate("text",x=2010,y=max(output$total_predicted_biomass$pred)*.9,label=paste("OFL = 0.27 * MMB = ",OFL_m,sep=""))
morph_plot<-plot_rema(tidy_rema=output)$biomass_by_strata+theme_bw()+ylab("Biomass 1,000 t")+
  annotate("text",x=2010,y=max(output$total_predicted_biomass$pred)*.9,label=paste("OFL = ",OFL_m,sep=""))
#=====================================
# Industry preferred
pref<-data.frame(biomass=com_male/1000,cv=com_male_cv,year=surv_yr,strata='EBS')
colnames(pref)<-c("biomass","cv","year","strata")
input<-prepare_rema_input(model_name='pref',biomass_dat=pref)
m<-fit_rema(input)
output<-tidy_rema(rema_model=m)
OFL_m<- round(.27*output$total_predicted_biomass[nrow(output$total_predicted_biomass),]$pred,2)


#==HCR OFL
#===calc BMSY and status
#===APPLY NATURAL MORTALITY OR NOT???
term_mmb<-output$total_predicted_biomass[nrow(output$total_predicted_biomass),]$pred
mmb_bmsy<-mean(filter(output$total_predicted_biomass,year<2025)$pred)
mmb_status<-term_mmb/mmb_bmsy
tmp<-data.frame(Year=output$total_predicted_biomass$year,
                rema_pred=output$total_predicted_biomass$pred,
                size='101')
keep_rema<-rbind(keep_rema,tmp)

22.63*exp(-(7/12)*nat_m)

#===find FOFL
beta<-0.25
alpha<-0.1
nat_m<-0.27
fofl_mmb_male<-nat_m
if(mmb_status<1)
{
  fofl_mmb_male <- 0
  if(mmb_status>beta)
    fofl_mmb_male <- nat_m * (mmb_status-alpha)/(1-alpha)
}
keep_status<-c(keep_status,mmb_status)
keep_fofl<-c(keep_fofl,fofl_mmb_male)
keep_bmsy<-c(keep_bmsy,mmb_bmsy)

OFL_m<- round(fofl_mmb_male*term_mmb,2)
OFL_dana<-nat_m*term_mmb*mmb_status

pref_plot<-plot_rema(tidy_rema=output)$biomass_by_strata+theme_bw()+ylab("Biomass 1,000 t")+
  annotate("text",x=2010,y=max(output$total_predicted_biomass$pred)*.9,label=paste("OFL = 0.27 * MMB = ",OFL_m,sep=""))
pref_plot<-plot_rema(tidy_rema=output)$biomass_by_strata+theme_bw()+ylab("Biomass 1,000 t")+
  annotate("text",x=2010,y=max(output$total_predicted_biomass$pred)*.9,label=paste("OFL = ",OFL_m,sep=""))
#==============================
# large males mature
large<-data.frame(biomass=lg_male/1000,cv=lg_male_cv,year=surv_yr,strata='EBS')
colnames(large)<-c("biomass","cv","year","strata")
input<-prepare_rema_input(model_name='large',biomass_dat=large)
m<-fit_rema(input)
output<-tidy_rema(rema_model=m)
OFL_m<- round(.27*output$total_predicted_biomass[nrow(output$total_predicted_biomass),]$pred,2)
#==HCR OFL
#===calc BMSY and status
#===APPLY NATURAL MORTALITY OR NOT???
term_mmb<-output$total_predicted_biomass[nrow(output$total_predicted_biomass),]$pred
mmb_bmsy<-mean(filter(output$total_predicted_biomass,year<2025)$pred)
mmb_status<-term_mmb/mmb_bmsy
tmp<-data.frame(Year=output$total_predicted_biomass$year,
                rema_pred=output$total_predicted_biomass$pred,
                size='95')
keep_rema<-rbind(keep_rema,tmp)
#===find FOFL
beta<-0.25
alpha<-0.1
nat_m<-0.27
fofl_mmb_male<-nat_m
if(mmb_status<1)
{
  fofl_mmb_male <- 0
  if(mmb_status>beta)
    fofl_mmb_male <- nat_m * (mmb_status-alpha)/(1-alpha)
}
keep_status<-round(c(keep_status,mmb_status),2)
keep_fofl<-round(c(keep_fofl,fofl_mmb_male),2)
keep_bmsy<-c(keep_bmsy,mmb_bmsy)

OFL_m<- round(fofl_mmb_male*term_mmb,2)
OFL_dana<-nat_m*term_mmb*mmb_status

large_plot<-plot_rema(tidy_rema=output)$biomass_by_strata+theme_bw()+ylab("Biomass 1,000 t")+
  annotate("text",x=2010,y=max(output$total_predicted_biomass$pred)*.9,label=paste("OFL = 0.27 * MMB = ",OFL_m,sep=""))
large_plot<-plot_rema(tidy_rema=output)$biomass_by_strata+theme_bw()+ylab("Biomass 1,000 t")+
  annotate("text",x=2010,y=max(output$total_predicted_biomass$pred)*.9,label=paste("OFL = ",OFL_m,sep=""))
png('plots/rema_tier_4_ssc.png',height=10,width=7,res=350,units='in')
morph_plot / large_plot / pref_plot
dev.off()

write.csv(keep_rema,"rema_outs.csv")
  