library(lubridate)
library(sqldf)
# flows
usgs_data <- dataRetrieval::readNWISuv(
  '02037500', parameterCd = '00060', 
  startDate = '2015-01-01', endDate = '2020-12-31'
)
siteNumber <- "02037500" # Example: USGS Potomac River at Point of Rocks, MD
parameterCd <- "00060"   # Discharge
startDate <- "2015-10-01"
endDate <- "2023-10-05"

# Retrieve hourly (unit value) data and save to drive
# hourlyData <- dataRetrieval::readNWISuv(siteNumber, parameterCd, startDate, endDate)
# write.csv(hourlyData, "C:/usr/local/home/git/estuarine/data/usgs_02037500_2015-2023.csv")
flow_file <- "https://raw.githubusercontent.com/HARPgroup/estuarine/refs/heads/main/data/usgs_02037500_2015-2023.csv"
# Analyze chesterfield
flow_dat <- read.csv(flow_file)
flow_dat$timestamp <- as.POSIXct(flow_dat$dateTime, tz = "EST")
flow_dat$yr <- year(as.Date(flow_dat$dateTime, tz = "EST"))
flow_dat$mo <- lubridate::month(as.Date(flow_dat$dateTime, tz = "EST"))
flow_dat$da <- lubridate::day(as.Date(flow_dat$dateTime, tz = "EST"))
flow_dat$hr <- lubridate::hour(as.POSIXct(flow_dat$dateTime, tz = "EST"))
flow_hourly <- sqldf("select yr, mo, da, hr, avg(X_00060_00000) as flow from flow_dat group by yr, mo, da, hr")

src_file <- paste0(github_location, "/vahydro/R/modeling/tidal_Fresh/particle2026/app_C_all.csv")
imp_dat <- read.csv(src_file)
names(imp_dat) <- c(
  "sample_date", "sample_id", "tidal_phase_start", "stratum", "taxon", "scientific_name", 
  "life_stage", "total_orgs", "density_org_numper100m3", "density_nonimp_numper100m3"
)
imp_dat$yr <- year(as.Date(imp_dat$sample_date, format="%m/%d/%Y", tz = "UTC"))
imp_dat$mo <- month(as.Date(imp_dat$sample_date, format="%m/%d/%Y", tz = "UTC"))
imp_dat$da <- lubridate::day(as.Date(imp_dat$sample_date, format="%m/%d/%Y", tz = "UTC"))
imp_dat$hr <- as.integer(substr(imp_dat$sample_id, 16, 17))

# Join flow data
imp_dat <- sqldf(
  "select a.*, b.flow from imp_dat as a 
   left outer join flow_hourly as b 
   on (
     a.yr = b.yr and a.mo = b.mo and a.da = b.da and a.hr = b.hr
   )
   order by a.sample_date, a.hr
  "
)

# isolate species/lifestages
pys_all <- sqldf("select * from imp_dat where life_stage = 'PYS'")
pys_tidal_phase <- sqldf(
  "select tidal_phase_start, sum(density_org_numper100m3) as dper100, 
   sum(density_nonimp_numper100m3) as niper100 
   from pys_all
   group tidal_phase_start
  "
)
pys_flood <- sqldf("select * from pys_all where tidal_phase_start='Flood'")
pys_ebb <- sqldf("select * from pys_all where tidal_phase_start='Ebb'")
plot(pys_all$total_orgs ~ log(pys_all$flow), ylim=c(0,15000))
plot(pys_flood$total_orgs ~ log(pys_flood$flow), ylim=c(0,15000))
plot(pys_ebb$total_orgs ~ log(pys_ebb$flow), ylim=c(0,15000))

pys_tidal_phase_mo <- sqldf(
  "select mo, tidal_phase_start, sum(density_org_numper100m3) as dper100, 
   sum(density_nonimp_numper100m3) as niper100 
   from pys_all
   group by mo, tidal_phase_start
  "
)
pys_tidal_phase_yr <- sqldf(
  "select yr, tidal_phase_start, sum(density_org_numper100m3) as dper100, 
   sum(density_nonimp_numper100m3) as niper100 
   from pys_all
   group by yr, tidal_phase_start
  "
)
pys_tidal_phase_yrmo <- sqldf(
  "select yr, mo, tidal_phase_start, sum(density_org_numper100m3) as dper100, 
   sum(density_nonimp_numper100m3) as niper100 
   from pys_all
   group by yr, mo, tidal_phase_start
  "
)
alosa_pys_all <- sqldf(
  "select * from pys_all
   where (
     (scientific_name like '%alosa%')
     OR (scientific_name like '%Clupeidae%')
   )
  "
)
alosa_pys_day_pct <- sqldf(
  "
    select a.sample_date, a.yr, a.mo, a.da, a.hr, a.tidal_phase_start, a.flow,
      a.total_orgs, b.daily_total_orgs, 
      (a.total_orgs / b.daily_total_orgs) as pct_of_daily 
    from alosa_pys_all as a
    left outer join (
      select yr, mo, da, cast(sum(total_orgs) as float) as daily_total_orgs
      from alosa_pys_all 
      group by yr, mo, da
    ) as b 
    on (
      a.yr = b.yr and a.mo = b.mo and a.da = b.da
    )
    order by a.yr, a.mo, a.da, a.hr
  "
)
alosa_pys_day_pct$sample_date <- as.Date(alosa_pys_day_pct$sample_date, format="%m/%d/%Y", tz = "UTC")

plot(alosa_pys_day_pct[which(alosa_pys_day_pct$tidal_phase_start == 'Ebb'),]$pct_of_daily )
points(alosa_pys_day_pct[which(alosa_pys_day_pct$tidal_phase_start == 'Flood'),]$pct_of_daily, col="blue",pch = 15 )
barplot(
  alosa_pys_day_pct[which(alosa_pys_day_pct$tidal_phase_start == 'Ebb'),]$pct_of_daily,
  alosa_pys_day_pct[which(alosa_pys_day_pct$tidal_phase_start == 'Flood'),]$pct_of_daily
)

ggplot(data = alosa_pys_day_pct, aes(x = sample_date, y = pct_of_daily, fill = tidal_phase_start)) +
  geom_col(position = "stack") +
  labs(title = "Stacked Bar Chart by Day",
       x = "Date",
       y = "Total Value") +
  scale_x_date(date_breaks = "1 year", date_labels = "%b %d") + # Format the date axis labels
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) # Rotate labels to prevent overlap


alosa_pys_tidal_phase_yrmo <- sqldf(
  "select yr, mo, tidal_phase_start, sum(density_org_numper100m3) as dper100, 
   sum(density_nonimp_numper100m3) as niper100 
   from alosa_pys_all
   group by yr, mo, tidal_phase_start
  "
)

pys_depth <- sqldf(
  "select stratum, sum(density_org_numper100m3) as dper100, 
   sum(density_nonimp_numper100m3) as niper100 
   from pys_all
   group by stratum
  "
)

