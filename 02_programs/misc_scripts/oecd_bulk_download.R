#bulk download of OECD SDG data
# data accessible from https://data-explorer.oecd.org/vis?lc=en&df[ds]=DisseminateFinalDMZ&df[id]=DSD_SDG%40DF_SDG&df[ag]=OECD.WISE.RSB&df[vs]=1.0&av=true
library(tidyverse)
library(here)

download_url <- 'https://sdmx.oecd.org/public/rest/data/OECD.WISE.RSB,DSD_SDG@DF_SDG,1.0/all?dimensionAtObservation=AllDimensions&format=csvfilewithlabels'

# download the data
download.file(download_url, destfile = here('01_raw_data','oecd_data','oecd_sdg_data.csv'), mode = 'wb')

#read in file
oecd_data <- read_csv(here('01_raw_data','oecd_data','oecd_sdg_data.csv'), col_names = TRUE)

#convert data to have seven columns:
# iso3c, date, goal, code, ind_value.oecd, ind_quality.oecd, ind_metadata.oecd

oecd_data_scored <- oecd_data %>%
  transmute(iso3c=REF_AREA,
         date=TIME_PERIOD,
         goal=SDG_GOAL,
         goal=str_replace(goal, 'G_', ''),
         #extract code from `SDG Indicator` column that looks like this. 3.c.1 Health worker density and distribution. JUst want everything before first space
         code=str_extract(`SDG indicator`, '^[^ ]+'),
         ind_value.oecd=OBS_VALUE,
         ind_quality.oecd=if_else(!is.na(ind_value.oecd),1,0),
         ind_metadata.oecd=Source
         ) %>%
  # if there is a '/' separate and then pivot longer
  separate_rows(code, sep = '/') %>%
  # remove any leading or trailing whitespace
  mutate(code = str_trim(code)) %>%
  #group by code and year and see if at least one value is available
  group_by(iso3c, date, goal, code) %>%
  #summarise the values
  summarise(ind_value.oecd = mean(ind_value.oecd, na.rm = TRUE),
            ind_quality.oecd = sum(ind_quality.oecd, na.rm = TRUE),
            ind_metadata.oecd = first(ind_metadata.oecd)) %>%
  mutate(ind_quality.oecd=if_else(ind_quality.oecd > 0, 1, 0)) 
         
#write out the data
write_csv(oecd_data_scored, here('01_raw_data','oecd_data','OECD_data_scored.csv'), na = '', col_names = TRUE)

#summarise by code ind_quality.oecd
sum <- oecd_data_scored %>%
  filter(between(date, 2020, 2024)) %>%
  group_by(iso3c, goal) %>%
  summarise(ind_quality.oecd = sum(ind_quality.oecd, na.rm = TRUE)) 

