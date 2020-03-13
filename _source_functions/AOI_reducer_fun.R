# Prefilter larger grid (lidar derived) to smaller area to match AOI
# Julian Scott 01/21/20 julian.a.scott@usda.gov or julianscotta@gmail.com

.reduce_to_AOI_fun <- function(AOI_extent,ToReduce_list,buffer){
  # add buffer to AIO_extent
  AOI_extent <- AOI_extent + buffer

  filter_fun <- function(df,ext){
    dfi = filter(df,X > xmin(ext) & X < xmax(ext))
    dfi = filter(dfi,Y > ymin(ext) & Y < ymax(ext))
    return(dfi)
  }
  
  result_dfs <- lapply(ToReduce_list,function(x) filter_fun(df = x,ext = AOI_extent))
  
  return(result_dfs)
}


