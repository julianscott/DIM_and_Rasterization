# Removes all instances of a cell being inundated by a smaller flow but not by the larger flows.
# Julian Scott 01/21/20 julian.a.scott@usda.gov or julianscotta@gmail.com

.cell_modulation_cleanup_fun <- function(cleanup_list,cleaned_grid_dir,scalars,overwrite){
  
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
  
  scalar_grids_list_clean <- list()
  for(s in scalars) {
    cleanup_s = cleanup_list[[s]]
    q_i = sapply(cleanup_s,function(x) names(x))
    # Function that takes two sequential rasters, raster1 and raster2, converts
    # each into 0s and 1s (0 = inundated, 1 = not inundated), then subtracts the
    # raster 1 from raster 2. Values of +1 are cells that are inundated in the
    # smaller raster but not the larger. The function then sets +1 cells
    # to NA in the smaller raster.
    clean_up_fun <- function(raster1,raster2){
      raster_tmp = is.na(raster1) # set smaller raster
      raster_tmp1 = is.na(raster2) # set larger raster
      # subtract smaller raster from next larger raster
      raster_delta = raster_tmp1 - raster_tmp
      # in raster_delta, values of:
      # 0 = cells are the same (ok)
      # -1 = smaller raster NA, larger raster non-NA (ok)
      # +1 = smaller raster non-NA, larger raster NA (bad)
      # Mask the smaller raster by raster_i, setting to NA all cells that are +1 in the mask
      raster_i = raster::mask(raster1,raster_delta,maskvalue = 1)
      return(raster_i)
    }
  
    # Set the second largest flows to prime the pump. Use function to set to NA those
    # cells that are inundated in the smaller but not the larger raster.
    tmp <- clean_up_fun(cleanup_s[[length(cleanup_s)-1]],cleanup_s[[length(cleanup_s)]])
    cleanup_s[[length(cleanup_s)-1]] <- tmp
  
    # Use function to set to NA those cells that are inundated in the smaller
    # but not the larger raster.
    # The for-loop works from the largest grid down to the smallest.
    # i=2
    for(i in 2:(length(cleanup_s)-1)){
      i = length(cleanup_s)-i
      clean_i = clean_up_fun(cleanup_s[[i]],cleanup_s[[i+1]])
      cleanup_s[[i]] = clean_i
    }
  
    # Code for testing for monotonic trends between sequential rasters
    # WSEStack <- raster::stack(WSE_combine)
    WSEStack <- raster::stack(cleanup_s)
  
    # Code for QAQC the results of the cleanup routine, or for evaluating the extent of the
    # need for the cleanup routine.
  
    # result_stack <- raster::stack()
    # for(layer in 1:(nlayers(WSEStack)-1)){
    #   raster_tmp = WSEStack[[layer]] # set raster_tmp to be the smaller raster
    #   raster_tmp[is.na(raster_tmp)] = 9000 # convert all na values to 9000
    #
    #   raster_tmp1 = WSEStack[[layer+1]] # set raster_tmp1 to be the larger raster
    #   raster_tmp1[is.na(raster_tmp1)] = 0 # convert all na values to 0
    #   # subtract smaller raster from next larger raster
    #   raster_i = raster_tmp1 - raster_tmp
    #   # in raster_i, values of:
    #   # -9000 = NA - NA (ok)
    #   # -7000 < value < -9000 = larger raster has larger inundating footprint than smaller raster (ok)
    #   # around -70 to -90  = larger r had a smaller inundating footprint than smaller r (!!!),
    #   # small negative numbers = larger r had lower WSE than smaller r (!!!)
    #   # positive numbers = larger r had larger WSE than smaller r (ok).
    #
    #   # -9000 = NA - NA (ok) - set to NA
    #   raster_i[raster_i == -9000] = NA
    #
    #   # -7000 < value < -9000 (ok)
    #   raster_i[raster_i < -1000 & raster_i != -9000] = NA
    #
    #   #around -70 to -90 (!!!)
    #   raster_i[raster_i > -1000 & raster_i < -50] = -1
    #
    #   # small negative numbers (!!!) - unchanged
    #   # raster_i[raster_i <= 0 & raster_i > -50] = NA
    #
    #   # positive numbers (ok) - set to NA
    #   raster_i[raster_i > 0] = NA
    #
    #   # Set the name of raster_i to be the name of the smaller raster.
    #   names(raster_i) = names(WSEStack[[layer]])
    #   result_stack = raster::stack(result_stack,raster_i)
    # }
  
    # For each layer in result_stack, get the number of cells that
    # are inundated in the smaller layer, but not the larger

    # sapply(1:nlayers(result_stack),function(x) length(result_stack[[x]][result_stack[[x]] == -1]))
  
    # Write and return cleaned list of rasters
    dir.create(file.path(cleaned_grid_dir,paste0(s,"_rasters")))
    clean_grid_names <- paste0(cleaned_grid_dir,"\\",s,"_rasters\\",q_i,".tif")
    
    sapply(1:length(cleanup_s),
           FUN = function(x) writeRaster(cleanup_s[[x]],filename = clean_grid_names[x],overwrite = overwrite))
    scalar_grids_list_clean[[s]] = cleanup_s
  }
  return(scalar_grids_list_clean)
}
