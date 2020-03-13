# Reads in formatted fastmech result csv files. Suffix containing "PY" indicates the file was derived from running fastmech in Python. If the
# file name does not contain the letters "PY", this indicates the file was exported from Iric and requires coordinate correction. THis is 
# accomplished in the code below.  If the files do not conform to this convention the code must be edited or else incorrect results may occur.
# Julian Scott 01/21/20 julian.a.scott@usda.gov or julianscotta@gmail.com
.read_fastmech_result_files <- function(files_for_processing,Iric_grid_export) {
  
  # get names of csv files in the working directory
  csv_result_names <- list.files(pattern = ".csv",full.name = T)
  csv_result_names_fornames <- list.files(pattern = ".csv",full.name = F)
  
  # get subset of files for processing
  if(length(files_for_processing) == 1) {
    if(files_for_processing == "AllFiles") {
      "do nothing"
    } else {
      csv_result_names <- grep(files_for_processing,csv_result_names,value = T)
      csv_result_names_fornames <- grep(files_for_processing,csv_result_names_fornames,value = T)
    }
  } else if(length(files_for_processing) > 1) {
    csv_result_names <- sapply(files_for_processing,function(x) grep(x,csv_result_names,value = T))
    csv_result_names_fornames <- sapply(files_for_processing,function(x) grep(x,csv_result_names_fornames,value = T))
  }
  
  # Print details.
  cat("Processing files: ",files_for_processing,"\n")
  cat("n = ",length(csv_result_names),"\n")
  cat("Files: ",csv_result_names,"\n")
  
  # Function to read each csv into list if files are already coordinated corrected for known Iric issue.
  # readCSV_fun <- function(list_of_csvs) {
  #   foreach (i = iter(list_of_csvs),.packages = 'tidyverse') %dopar% {
  #     df_i <-  tryCatch({read.csv(i,header = T,colClasses = c("numeric"))},
  #                       error = function(e){read.csv(i,skip = 2,header = T)})
  #     df_i
  #   }
  # }
  # system.time({
  #   UseCores <- detectCores() - 1
  #   cl <- makeCluster(UseCores)
  #   registerDoParallel(cl)
  #   result_dfs <- readCSV_fun(list_of_csvs = csv_result_names_fornames)
  #   stopCluster(cl)
  #   names(result_dfs) <- csv_result_names_fornames
  # })
  
  # Use if files are NOT already coordinated corrected for known Iric issue.
  # read in Iric_grid_export; update I and J index convention.
  Iric_grid_export <-  fread(Iric_grid_export,header = T,colClasses = c("numeric"),skip = 2) %>%
    filter(K == 0) %>%
    mutate(I = I +1, # survey_grid uses 0 for first index. Make it 1.
           J = J + 1)
  
  # i = csv_result_names[1]
  # Define the number of decimal places to round the XY coordinates to.
  XY_dec = 2 # (2=centimeters for UTM meters)
  
  # Define the number of decimal places to round the scalar result data to.
  Result_dec = 3
  
  # Read each csv into list
  readCSV_fun <- function(csv_result_names,Iric_grid_export,XY_dec,Result_dec) {
    foreach (i = iter(csv_result_names),.packages = c('data.table','tidyverse')) %dopar% {
      # If the suffix "PY" is found in the csv name, then read csv with header,
      # round X,Y,Z and scalar results to defined number of decimal places.
      # This rounding can be critical for achieving identical processing for PY and Iric derieved results.
      if(grepl("PY",i) == TRUE){
        df_i = fread(i,header = T) %>%
          mutate_at(vars(X,Y),~round(.,XY_dec)) %>%
          mutate_at(vars(Elevation,Depth:ShearStress),~round(.,Result_dec))
      } else {
        # If the suffix "PY" is not found in the csv name, then read csv with header and skip two lines,
        # select the given columns (Must match columns in PY csv files), round the data, then replace
        # py_result_df coordinates with surv_grid coordinates. This step is required because, according to
        # iRIC developers, when exporting results, the iRIC software truncates XY coordinates and then
        # reports erroneous values to the right of the decimal place.
        df_i = fread(i,header = T,skip = 2) %>%
          rename("Velocity" = "Velocity (magnitude)",
                 "ShearStress" = "ShearStress (magnitude)",
                 "UnitDischarge" = "UnitDischarge (magnitude)") %>%
          mutate_at(vars(X,Y),~round(.,XY_dec)) %>%
          mutate_at(vars(Elevation,Depth:ShearStress),~round(.,Result_dec))
        # replace py_result_df coordinates with surv_grid coordinates
        Iric_grid_export2 <- dplyr::select(Iric_grid_export,-c(K,Z))
        # Test that I and J order is same for both and report error if not!!!
        if(isTRUE(all.equal(df_i$I,Iric_grid_export2$I)) & isTRUE(all.equal(df_i$J,Iric_grid_export2$J))) {
          df_i = df_i
        } else {
          return(print("Grid IJ differs from Py IJ!! Does your Iric_grid_export match your result file?"))
        }
        df_i_tmp <- df_i %>%
          dplyr::select(-c(X,Y,I,J))
        df_i <- cbind(Iric_grid_export2,df_i_tmp)
      }
      df_i
    }
  }
  
  #Use Parallel processing to run the function
  system.time({
    UseCores <- detectCores() - 1
    cl <- makeCluster(UseCores)
    registerDoParallel(cl)
    result_dfs <- readCSV_fun(csv_result_names,Iric_grid_export,XY_dec,Result_dec)
    stopCluster(cl)
    names(result_dfs) <- csv_result_names_fornames
  })
  # Print details.
  return(result_dfs)
}
