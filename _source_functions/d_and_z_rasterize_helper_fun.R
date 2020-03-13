# Calculates the mean of the four adjacent cells for treatment cells (drops NAs/NaNs)
# Julian Scott 01/21/20 julian.a.scott@usda.gov or julianscotta@gmail.com
.d_and_z_rasterize_helper_fun <- function(Raster,directions,treatment){
  # First, ID those cells that are flagged as cells with no point (either NaN for the Type1 mask or NA for the primary rasterization)
  if(is.nan(treatment) == T){
    bgc_Nbs <- Which(is.nan(Raster),cells = T)
  } else if(is.na(treatment == T)) {
    bgc_Nbs <- Which(is.na(Raster),cells = T)
  }
  
  # For each background cell (from) get the adjacent cells (to)
  bgc_adj <- raster::adjacent(Raster,cells = bgc_Nbs,
                              directions = directions,
                              pairs = T,
                              id = F,
                              include = F,
                              sorted = T)
  # Get adjacent cell values, but remove adjacent cells that are NA (bc they don't contain a point)
  bgc_adj_wActiveNbs <- as.data.frame(bgc_adj)
  bgc_adj_wActiveNbs$adj_val <- Raster[bgc_adj_wActiveNbs$to]
  bgc_adj_wActiveNbs <- bgc_adj_wActiveNbs[!is.na(bgc_adj_wActiveNbs$adj_val),]
  
  # head(bgc_adj_wActiveNbs)
  # str(bgc_adj_wActiveNbs)
  
  little_d_and_z_rasterize_helper_fun <- function(backgrnd_adj_tble){
    mean_depths <- foreach(i = iter(unique(backgrnd_adj_tble$from)),
                           .combine = c) %dopar% {
                             mean(backgrnd_adj_tble[backgrnd_adj_tble$from == i,]$adj_val)
                           }
    return(mean_depths)
  }
  

  system.time({
    UseCores <- detectCores() - 1
    cl <- makeCluster(UseCores)
    registerDoParallel(cl)
    mean_depths <- little_d_and_z_rasterize_helper_fun(backgrnd_adj_tble = bgc_adj_wActiveNbs)
    stopCluster(cl)  
  })

    update_vals <- data.frame(from = unique(bgc_adj_wActiveNbs$from), new_val = mean_depths)  
  
  # assign raster to new object for work
  r_iFill1 <- Raster
  r_iFill1[update_vals$from] <- update_vals$new_val
  # plot(Raster,colNA = "black")
  # plot(r_iFill1,colNA = "black")
  return(r_iFill1)
}