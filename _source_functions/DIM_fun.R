# Digital Inundation Model (DIM) function
# Julian Scott 01/21/20 julian.a.scott@usda.gov or julianscotta@gmail.com
.DIM_fun <- function(raster_list,DIM_grid_dir){
  # For creating DIM of aerial extent of all inundation levels, first use the 
  # following reclassification that will change non NA values to the value of Q, and create
  # raster of just the edge.
  raster_list_bi <- sapply(raster_list,function(x) {
    # create numeric object q, equal to the discharge of iric ouput i. 
    q <- as.numeric(str_replace(names(x), regex(".+cms", dotall = TRUE),""))
    # set non NA cells to a single value, to limit the number of value classes to 2: q and NA
    x[!is.na(x)] <- as.numeric(q)
    # Create a raster reflecting the boundary cells of the inundating area; all other cells are set to NA
    x <- boundaries(x,asNA = TRUE,directions = 4,classes = F) #,classes = T
    # set non NA cells to discharge, q
    x[!is.na(x)] <- as.numeric(q)
    # update the name of the new raster to include the units of the discharge measure
    names(x) <- paste0("cms",q) 
    return(x)
  }
  )
  
  # reclass to q value only; this is useful for viewing inundated footprint as solid block of single color
  raster_list_full <- sapply(raster_list,function(x) {
    # create numeric object q, equal to the discharge of iric ouput i. 
    q <- as.numeric(str_replace(names(x), regex(".+cms", dotall = TRUE),""))
    # set non NA cells to a single value, to limit the number of value classes to 2: q and NA
    x[!is.na(x)] <- as.numeric(q)
    # update the name of the new raster to include the units of the discharge measure
    names(x) <- paste0("cms",q) 
    return(x)
  }
  )
  
  # Build DIM from boundary rasters
  
  # Code to merge the rasters of sequential ascending discharge levels. 
  # Priority in the case of overlaps is given to argument order (which is why sequential ascending qs is critical)
  # See critical note below on sequential ascending q levels
  
  # CRITICAL: The sequential layers of inundating discharge surfaces has an order that is inherited when it is read in from the directory.
  # CRTIICAL: Therefore, the naming convention of the IRIC output csv files must be such that they are ordered correctly 
  # CRITICAL: E.g., when viewing the csvs in File Explorer, when the folder is sorted by name, are they in the correct ascending order?
  # CRITICAL: We achieve this using the following convention, IRICoutput_0000.01, IRICoutput_0001.5, IRICoutput_0010.0,IRICoutput_1010.0, etc
  # There are many other ways to do this, but this is how the code we have written works for now. 
  
  # Merge() requires adding each raster as an individual argument separated by a comma,
  # we will use do.call() to run the merge function. 
  
  raster_list_bi_Qdagwood <- raster_list_bi
  names(raster_list_bi_Qdagwood) <- NULL
  DIM_bound <- do.call(raster::merge,raster_list_bi_Qdagwood)
  # Write DIM_bound to disc
  DIM_bound_names <- paste0(DIM_grid_dir,"\\DIM_boundary.tif")
  writeRaster(DIM_bound,filename = DIM_bound_names)
  
  
  raster_list_full_Qdagwood <- raster_list_full
  names(raster_list_full_Qdagwood) <- NULL
  DIM_full <- do.call(raster::merge,raster_list_full_Qdagwood)
  # Write DIM_full to disc
  DIM_full_names <- paste0(DIM_grid_dir,"\\DIM_full.tif")
  writeRaster(DIM_full,filename = DIM_full_names)
  
  Q_Dagwood_bound_points <- rasterToPoints(DIM_bound,spatial = TRUE)
  # write points to disc
  st_write(st_as_sf(Q_Dagwood_bound_points),paste0(DIM_grid_dir,"\\DIM_bound_points.shp"))
  
  DIM_products = list(DIM_bound,DIM_full,Q_Dagwood_bound_points)
  names(DIM_products) = c("DIM_bound","DIM_full","Q_Dagwood_bound_points")
  return(DIM_products)
}
