library(lubridate)
# flows
usgs_data <- dataRetrieval::readNWISuv(
  '02037500', parameterCd = '00060', 
  startDate = '2015-01-01', endDate = '2020-12-31'
)
siteNumber <- "02037500" # Example: USGS Potomac River at Point of Rocks, MD
parameterCd <- "00060"   # Discharge
startDate <- "2015-10-01"
endDate <- "2023-10-05"

# Retrieve hourly (unit value) data
hourlyData <- dataRetrieval::readNWISuv(siteNumber, parameterCd, startDate, endDate)

# Analyze chesterfield
src_file <- paste0(github_location, "/vahydro/R/modeling/tidal_Fresh/particle2026/app_C_all.csv")
imp_dat <- read.csv(src_file)
names(imp_dat) <- c(
  "sample_date", "sample_id", "tidal_phase_start", "stratum", "taxon", "scientific_name", 
  "life_stage", "total_orgs", "density_org_numper100m3", "density_nonimp_numper100m3"
)
imp_dat$yr <- year(as.Date(imp_dat$sample_date, format="%m/%d/%Y", tz = "UTC"))
imp_dat$mo <- month(as.Date(imp_dat$sample_date, format="%m/%d/%Y", tz = "UTC"))
pys_all <- sqldf("select * from imp_dat where life_stage = 'PYS'")
pys_tidal_phase <- sqldf(
  "select tidal_phase_start, sum(density_org_numper100m3) as dper100, 
   sum(density_nonimp_numper100m3) as niper100 
   from pys_all
   group tidal_phase_start
  "
)

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
barplot()