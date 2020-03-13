# Rasterize irregularly spaced points into a regular grid.
# Julian Scott 01/21/20 julian.a.scott@usda.gov or julianscotta@gmail.com

.fastmech_rasterize_fun <- function(formatted_fastmech_files,res,projr,scalars,subdir1,overwrite){
  # Print details
  cat("Resolution: ",res,"\n")
  cat("Projection: ",as.character(projr),"\n")
  
  # create vector of names.
  q_i = data.frame(tmpName = names(formatted_fastmech_files)) %>%
    mutate(newName = if_else(grepl("PY1",tmpName) == TRUE,sub("Result_","",sub("_PY1.csv","",tmpName)),
                             if_else(grepl("PY2",tmpName) == TRUE,sub("Result_","",sub("_PY2.csv","",tmpName)),
                                     sub("Result_","",sub(".csv","",tmpName))))) %>%
    dplyr::select(newName)
  q_i <- q_i[[1]]
  
  # If rasterizing all scalars, convert variable into vector of all variable names
  if(length(scalars) == 1) {
    if(scalars == "Everything") {
      scalars <- c("Depth","WaterSurfaceElevation", "VelocityX","VelocityY","ShearStressX","ShearStressY","Velocity","ShearStress")
    } else {
      scalars <- scalars
    }
  } else if(length(scalars) > 1) {
    scalars  <- scalars
  }
  # Print scalars to rasterize.
  cat("Scalars to rasterize: n = ",length(scalars),"\n")
  cat(paste(as.character(scalars), collapse=", "),"\n")
  
  scalar_folders <- paste0(scalars,"_rasters")
  
  # confirm that all scalar names are in the file header variabe names
  scalar_check_fun <- function(x) {
    if(all(x %in% names(formatted_fastmech_files[[1]]) == FALSE))
      stop("Chosen scalars are not valid variable names. Cross check chosen scalars with headers. If there
         is still an issue, confirm headers of result files are as listed on line 36 and/or see the
         variable name transformations that occur in the readCSV_fun above.")
  }
  scalar_check_fun(scalars)
  
  # Function to create folder names from scalars if they don't already exist
  if(subdir1 == ""){
    sapply(scalar_folders,function(x) dir.create(file.path(getwd(),x)))
  } else {
    dir.create(file.path(getwd(),subdir1))
    sapply(scalar_folders,function(x) dir.create(file.path(getwd(),subdir1,x),showWarnings = F))
  }
  
  # create an empty raster with the extent, resolution, and projection of the iric mesh.
  forextent <- formatted_fastmech_files[[1]]
  e <- extent(with(forextent,c(min(X),max(X),min(Y),max(Y))))
  
  r <- raster(x = e,resolution = res,crs = projr)
  # Primary Rasterization function.
  # 1. if Depth = 0, NA
  # 2. if multiple points in cell, take mean (drop NAs)
  # 3. if background, NaN
  
  rasterize_fun_par <- function(df_list,r,val,projr,overwrite) {
    foreach (i = iter(names(df_list))) %dopar% {
      df_i <-  df_list[[i]]
      # name_i = sub("Result_","cms",sub(".csv","",i))
      rize_i <- raster::rasterize(x = df_i[,c("X","Y")],y = r,
                                  field = ifelse(df_i[,"Depth"] <= 0,NA,df_i[,val]),
                                  fun = mean,
                                  background = -999,
                                  na.rm = T,
                                  format = "GTiff",
                                  overwrite = overwrite)
      # convert background values to NaN
      rize_i <- raster::reclassify(rize_i, cbind(-Inf, 0, NaN), right=FALSE)
      # names(rize_i) = name_i
      return(rize_i)
    }
  }
  
  # Type 1 Mask rasterize function:
  # 1. if depth > 0, 1
  # 2. if depth = 0, NA
  # 3. if multiple points in cell, take mean (KEEP NAs; ie, if both inactive
  #     and active points present, NA).
  # 4. If background, NA.
  # The result will be used to mask what I am calling Type 1 errors, where a background
  # cell is Active even though it is surrounded by Inactive points.
  Type1_mask_fun <- function(df_list,r,projr) {
    foreach (i = iter(names(df_list))) %dopar% {
      df_i =  df_list[[i]]
      rize_NAi = raster::rasterize(x = df_i[,c("X","Y")],y = r,
                                   field = ifelse(df_i[,"Depth"] <= 0,NA,1),
                                   fun = mean,
                                   background = NA,
                                   na.rm = F,
                                   format = "GTiff")
    }
  }
  
  # Rasterize point files for each chosen scalars. Add results to list.
  rasterize_scalar_list <- list()
  for(s in scalars) {
    # 1.7 min for 24
    system.time({
      UseCores <- detectCores() - 1
      cl <- makeCluster(UseCores)
      registerDoParallel(cl)
      rize_l <- rasterize_fun_par(formatted_fastmech_files,r,val = s,projr,overwrite = overwrite)
      Type1_mask_l <- Type1_mask_fun(formatted_fastmech_files,r,projr)
      stopCluster(cl)
    })
    
    # took an 2.36 min for 24
    # Raster,directions,treatment
    system.time({
      # For each background cell, calculate mean WSE of 4 adjancent cells (drop NAs)
      focal_l <- lapply(rize_l,function(x) .d_and_z_rasterize_helper_fun(Raster = x,
                                                                         directions = 4,
                                                                         treatment = NaN))
      # For each background cell in the Type1 mask, calculate mean WSE of 4 adjancent cells
      # (do NOT drop NAs).Produces a raster where cells that contain at least one point Depth = 0 are NA.
      # All other cells are 1.
      f_Type1_mask_l <- lapply(Type1_mask_l,function(x) .d_and_z_rasterize_helper_fun(x,4,NA))
    })
    
    # Set Type 1 errors to NA by masking the focal_l by the f_Type1_mask_l.
    mask_l <- list()
    for(i in 1:length(rize_l)){
      mask = raster::mask(focal_l[[i]],f_Type1_mask_l[[i]],maskvalue = NA)
      mask_l[[i]] = mask
    }
    
    # update raster value names 
    mask_l <- sapply(1:length(mask_l),function(x) {
      names(mask_l[[x]]) = paste0(s,"_cms",q_i[x])
      return(mask_l[x])
    })
    
    # Assign names to the results list
    names(mask_l) <- paste0("cms",q_i)
    
    # Write files to disc
    result_names <- paste0(".\\",subdir1,"\\",s,"_rasters\\",s,"_",paste0("cms",q_i),".tif")
    sapply(1:length(mask_l),
           FUN = function(x) writeRaster(mask_l[[x]],result_names[x],overwrite = overwrite))
    
    rasterize_scalar_list[[s]] =  mask_l
    
  }
  
  return(rasterize_scalar_list)
  
}