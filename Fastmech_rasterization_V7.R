#  Script for rasterizing Fastmech result files. 
# Julian Scott 01/21/20 julian.a.scott@usda.gov or julianscotta@gmail.com

packages <- c("raster","rgeos","rgdal","sf","spatstat","spdep","tidyverse","rasterVis","ggplot2",'ggsn',"sp","data.table","doParallel","sp")

#  Check to see if each is installed, and install if not.
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {    
  install.packages(setdiff(packages, rownames(installed.packages())))  
}

# load the installed libraries in the packages list 
lapply(packages,library,character.only=TRUE)

#########################################################
# Before proceeding, confirm:
# 1. Fastmech csv files are in the format Result_00001.5.csv, where the number of leading zeros
# can be more or less, as long as the total number of characters to the left of the decimal is consitent and 
# accomodates the largest flow values. Having the suffix *_PY1.csv, *_PY2.csv, or just *.csv is acceptable.

# This code assumes that some of the fastmech result files include files output from the Iric GUI that require coordinate
# correciton. The script recognizes these files by the absence of the '_PY' suffix in the file name.  
#########################################################

#########################################################
# Edit code below to get desired results.
#########################################################
# A. Set working directory to directory that contains fastmech csv result files. 
# If the Rasterization_and_DIM project file is opened, the default working directories work. 

# setwd("F:\\_DoD\\_Camp_Pendleton_Survey\\IRIC\\_Modeling_dir\\_LowFlows_Model_v2\\Python_Directory\\_solution_files_LiDAR\\")
# q2918
# setwd("F:\\_DoD\\_Camp_Pendleton_Survey\\IRIC\\_Modeling_dir\\_LowFlows_Model_v2\\Python_Directory\\q2918\\")
# setwd("G:\\Reynolds_SERDP\\Data\\Hydraulic_mods\\SALFloodplainSurvey\\_Office_work\\iRIC\\Incremental Flows FastMech models\\SAL_DagwoodLiDAR\\")

# B. Set source for functions
# Open files in Rstudio to view and edit these functions.
source_funs <- list.files(path = ".\\_source_functions",
                          pattern = ".R",full.names = T)
# source_funs <- list.files(path = "F:\\_DoD\\_Camp_Pendleton_Survey\\IRIC\\_Modeling_dir\\_LowFlows_Model_v2\\Python_Directory\\Rasterization_and_DIM\\_source_functions",
                          # pattern = ".R",full.names = T)
invisible(lapply(source_funs,function(x) source(x)))

# C. Specify location of Iric grid export file. 
# This is necessary for when result files need to be coordinate-corrected for known Iric issue.
Iric_grid_export <-".\\iRIC_exported_grid\\SMR_IRIC_LIDAR_GRID_EXPORT.csv"
# Iric_grid_export <-"F:\\_DoD\\_Camp_Pendleton_Survey\\Sharing_Fastmech_methods\\Example\\iRIC_exported_grid\\Grid_Iric.csv"
# Iric_grid_export <-"F:\\_DoD\\_Camp_Pendleton_Survey\\IRIC\\_Modeling_dir\\_LowFlows_Model_v2\\Python_Directory\\Iric_LIDAR_grid\\IRIC_LIDAR_GRID_EXPORT.csv"


# D. Define scalar(s) variable to rasterize. Spelling must match the following list. Use 'Everything' to rasterize all.
# "Depth","WaterSurfaceElevation", "VelocityX","VelocityY","ShearStressX","ShearStressY","Velocity","ShearStress"   
# scalars <- c("WaterSurfaceElevation","Depth")
scalars <- c("WaterSurfaceElevation")
# scalars <- "Everything"

# E. Set resolution and projection of raster output
# res <- c(0.5,0.5)
res <- c(1,1)
projr <- sp::CRS("+proj=utm +zone=10 +datum=WGS84 +units=m +no_defs +ellps=WGS84 +towgs84=0,0,0")
# projr <- CRS("+proj=utm +zone=12 +units=m +no_defs +ellps=GRS80")

# F. Code assumes that all fastmech files in the defined working directory will be rasterized. To just rasterize
# a subset, define here. Else leave as "AllFiles"
files_for_processing <- "AllFiles"
# files_for_processing <- c("Result_00001.0.csv","Result_00001.3.csv","Result_00002.6_PY2.csv")
# files_for_processing <- "Result_00540.0_PY2.csv"

# G. Optional sub directory for placing results
subdir1 <- "OutputTestFolder"
# subdir1 <- ""
 
# H. Option to reduce AOI
# Area of Interest to reduce the larger grids to can be defined by reading in an existing raster.
# AOI_extent <- raster::extent(raster::raster(choose.files()))
AOI_extent <- raster::extent(c(1033824 ,1033892 ,3709915,3710001))
# Additional buffer to add to AOI. 
buffer <- 0

##################################################################################################################
# Run each step below line by line. Code does not need modification unless options or customization desired.
##################################################################################################################

# 1. Read in fastmech result files and save as list of dataframes
formatted_fastmech_files <- .read_fastmech_result_files(files_for_processing = files_for_processing,
                                                        Iric_grid_export = Iric_grid_export)

head(formatted_fastmech_files[[1]])

# 2. Option to reduce the grid size if desired
formatted_fastmech_files <- .reduce_to_AOI_fun(AOI_extent = AOI_extent,
                                               ToReduce_list = formatted_fastmech_files,
                                               buffer = buffer)

# 3. Rasterize the scalars for each fastmech file and write to working directory.
# Produces a nested list, one list of results for each scalar.
scalar_grids_list <- .fastmech_rasterize_fun(formatted_fastmech_files = formatted_fastmech_files,
                        res = res,
                        projr = projr,
                        scalars = scalars,
                        subdir1 = subdir1,
                        overwrite = T)

# plot(scalar_grids_list[[1]][[1]],colNA = "black",main = names(scalar_grids_list[[1]][[1]]))
par(mfrow=c(2,2)) 
lapply(scalar_grids_list[[1]],function(x) plot(x,colNA = "black",
                                               main = names(x)))


# 4. Trim grids to eliminate cells modulating from active to inactive. 
# Use results of the .fastmech_rasterize_fun directly or read in a list of appropriatly formatted grids
# from a directory (4A Read Option).

#################################################################################
# 4A Read Option: read in results from a directory. 
# If you want to use Read Option, uncomment the following 5 lines of code. Update directory to point to desired tifs.

# scalar_grids_names <- list.files("E:/_DoD/_Camp_Pendleton_Survey/IRIC/_Modeling_dir/_LowFlows_Model_v2/Python_Directory/pre_clean_grids_011920/",pattern = ".tif",full.names = T)
# scalar_grids_list <- list(lapply(scalar_grids_names,function(x) raster::raster(x)))
# cleaned_grid_dir <- file.path(getwd(),subdir1,"cleaned_grids")
# dir.create(cleaned_grid_dir)
# cleaned_grid_list <- .cell_modulation_cleanup_fun(cleanup_list = scalar_grids_list,
#                                              cleaned_grid_dir = cleaned_grid_dir,
#                                              scalars = scalars)
#################################################################################

#################################################################################
# 4B: Use results of step 3.
# Produces a nested list, one list of results for each scalar.
cleaned_grid_dir <- file.path(getwd(),subdir1,"_cleaned_grids")
dir.create(cleaned_grid_dir)
cleaned_grid_list <- .cell_modulation_cleanup_fun(cleanup_list = scalar_grids_list,
                                             cleaned_grid_dir = cleaned_grid_dir,
                                             scalars = scalars,
                                             overwrite = T)

# plot(cleaned_grid_list[[1]][[1]],colNA = "black",main = paste0("Trimmed",names(cleaned_grid_list[[1]][[1]])))
# click(xy = T)
# length(cleaned_grid_list[[1]])
# par(mfrow=c(2,2)) 
lapply(cleaned_grid_list[[1]],function(x) plot(x,colNA = "black",
                                          main = paste0("Trimmed",names(x))))

#################################################################################


# 5.  Create a  digital inundation model. Read in or define properly formatted grids.
#################################################################################
# 5A Read Option: read in results from a directory. 
# If you want to use Read Option, uncomment the following lines of code. Update directory to point to desired tifs.

# DIM_grids_names <- list.files("E:\\_DoD\\_Camp_Pendleton_Survey\\IRIC\\_Modeling_dir\\_LowFlows_Model_v2\\Python_Directory\\cleaned_grids\\WaterSurfaceElevation_rasters\\",
#                                  pattern = ".tif",full.names = T)
# DIM_grids_list <- lapply(DIM_grids_names,function(x) raster::raster(x))
# DIM_grids_list <- cleaned_grid_list$WaterSurfaceElevation
# DIM_products <- .DIM_fun(raster_list = DIM_grids_list)

#################################################################################
# 5B: Use results of step 4.
DIM_grid_dir <- file.path(getwd(),subdir1,"_DIM_products")
dir.create(DIM_grid_dir)

# It shouldn't matter which scalar you create a DIM from, so scalar 1 is hardcoded.
DIM_grids_list <- cleaned_grid_list[[1]]
DIM_products <- .DIM_fun(raster_list = DIM_grids_list,DIM_grid_dir = DIM_grid_dir)
par(mfrow = c(1,1))
par(mar = c(3,3, 2, 1))
plot(DIM_products$DIM_bound,colNA = "black")
plot(DIM_products$DIM_full,colNA = "black")


#################################################################################
# In development 
###########################################
# Get resample Velocity Grid to 0.5 cms
# SMR
# choose.files()
# resample_template <- raster("E:\\_DoD\\_Camp_Pendleton_Survey\\IRIC\\_Modeling_dir\\_LowFlows_Model_v2\\Python_Directory\\_FinalGrids\\trimmed_WSE_rasters\\WaterSurfaceElevation_cms03000.0.tif")
# # resample_template <- raster("F:\\Reynolds_SERDP\\Data\\Hydraulic_mods\\SALFloodplainSurvey\\_Office_work\\iRIC\\Incremental Flows FastMech models\\_FinalGrids\\WSE_rastersV2\\WSE_cms0000.31.tif")
# 
# resample_template
# scalar_grids_list[[1]][[1]]
# plot(resample_template,colNA = "black")
# plot(scalar_grids_list[[1]][[1]],colNA = "black")
# 
# Vel_rsmpled <- raster::resample(scalar_grids_list[[1]][[1]],resample_template)
# plot(Vel_rsmpled)
# plot(resample_template,add = T)
# writeRaster(Vel_rsmpled,filename = ".\\Output_files_012320\\Velocity_rasters\\SMR50cm_Velocity_cms03000.0.tif")


# SAL
# choose.files()
# resample_template <- raster("E:\\_DoD\\_Camp_Pendleton_Survey\\IRIC\\_Modeling_dir\\_LowFlows_Model_v2\\Python_Directory\\_FinalGrids\\trimmed_WSE_rasters\\WaterSurfaceElevation_cms03000.0.tif")
# # resample_template <- raster("F:\\Reynolds_SERDP\\Data\\Hydraulic_mods\\SALFloodplainSurvey\\_Office_work\\iRIC\\Incremental Flows FastMech models\\_FinalGrids\\WSE_rastersV2\\WSE_cms0000.31.tif")
# 
# resample_template
# scalar_grids_list[[1]][[1]]
# plot(resample_template,colNA = "black")
# plot(scalar_grids_list[[1]][[1]],colNA = "black")
# 
# Vel_rsmpled <- raster::resample(scalar_grids_list[[1]][[1]],resample_template)
# plot(Vel_rsmpled)
# plot(resample_template,add = T)
# writeRaster(Vel_rsmpled,filename = ".\\Output_files_012320\\Velocity_rasters\\SMR50cm_Velocity_cms03000.0.tif")
















