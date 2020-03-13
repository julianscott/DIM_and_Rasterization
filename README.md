# DIM_and_Rasterization

this code was designed to 
•	convert one or many fastmech result csv files into rasters. 
•	correct the known issue of iRIC exporting incorrect coordinates when results are exported directly from iRIC
•	reduce the extent of the original fastmech result file down to a smaller area of interest (from a larger LiDAR extent down to a smaller surveyed extent, for example).
•	create rasters from subsets or all of the scalar results output by fastmech (i.e. Depth, WaterSurfaceElevation, etc.).  
•	provide the option to “clean up” cells that modulate back and forth from being Inundated to Inactive in a sequence of increasing discharges rasters. 
•	provide the option to create a Digital Inundation Model (both the boundary or the full inundating footprint) from the set of rasters.  
 
Here is a quick outline of the workflow.
1.	Identify the working directory that contains the properly formatted fastmech result csv files that you want to process (i.e. “.\\_solution_files”). 
2.	Place the contents of the Rasterization_and_DIM folder into working directory. 
3.	Replace the contents of the iRic_exported_grid folder with your own iric exported grid (File >- Export > Grid > *.csv).
4.	Open the Rasterization_and_DIM.Rproj in RStudio.
5.	Open the Fastmech_rasterization_V7.R. This is the main code for running the workflow. It accesses functions that are stored in the _source_functions folder automatically, as long as the _source_function folder is in the working directory with the Rasterization_and_DIM.Rproj and the fastmech result csv files. 
6.	Follow along the annotated code. 
Set up specifics
a.	Set working directory, if different from location of Rasterization_and_DIM.Rproj
b.	Set directory containing source functions
c.	Set directory containing the iric-exported grid, which is used for correcting coordinates in fastmech result csv files exported from iric.
d.	Select scalars for which you want to create grids
e.	Set resolution and projection options
f.	Select the fastmech result csv files that you want to process. Use “AllFiles” to process all files. 
g.	Set subdirectory that the code will create to store output folders and files.
h.	Optional. Reduce the area of interest if desired. This option was written specifically for reducing a large lidar-derived grid for a long reach down to smaller area of interest determined by the extent of an existing raster. 
Begin workflow
1.	Read in fastmech result files and save as list of dataframes using .read_fastmech_result_files function.
2.	Reduce AOI if desired.
3.	Rasterize the scalars for each fastmech file and write to working directory using .fastmech_rasterize_fun
4.	Step 4 is optional.  Depending on the interval of discharges that are modeled, there may be cells that are inundated by a small discharge, but not by larger discharges. These are referred to modulating cells. Step 4 in the workflow identifies these cells and sets them to NA (i.e. not inundated) in the smaller raster. It effectively “trims” all grids such that there are no modulating cells. Once they become active, they remain active. The source code for this function contains code for analyzing a sequence of grids to evaluate the extent of this issue for the dataset. To do this, the user must open the source function, copy it to a new r file to preserve the original, and edit the code as desired.
5.	Create a boundary DIM raster from selected scalar results. The code will also produce a  boundary DIM point shapefile. This shapefile can be used to create a TIN in ArcGIS. The TIN can be exported as a raster to produce what is currently considered the best-practice Digital Inundation Model.

Here are some details for how the code rasterizes the irregularly spaced points to a regular grid:
•	Primary rasterization function:
	Cells containing a single points with Depth = 0 are set to NA.
	For cells that contain multiple fastmech points, take the mean of the points. If one of the points is NA, drop the NA from the calculation.
	Background cells (those cells that do not intersect a fastmech point) are set to NaN (which is different from NA).

•	Type1_mask_fun rasterization function:
o	Create a raster that will be used to identify and correct the situation (what I’m calling Type 1 Errors) in the primary rasterization function where a background cell is set to active even though it is surrounded by inactive points. 
	Points with Depth = 0 are set to NA. Depth > 0 set to 1.
	For cells that contain multiple fastmech points, take the mean of the points. If one of the points is NA, drop it from the calculation.
	Background cells (those cells that do not intersect a fastmech point) are set to NA
•	For background cells in both the primary and type1_mask rasters, use a custom focal statistics script to calculate the mean of the four adjacent cells (removing NA values from the calculation).
•	Set to NA all cells in primary raster that are incorrectly set to Active because of the special situation where a background cell that is adjacent to a cell that contains both an active and inactive point is ACTIVE, even when the four closest points surrounding the cell are Inactive. (I.e. Type 1 Error described above).

For addressing the issue of cells having modulating inundation I wrote a script, which runs before the DIM creation, that goes pairwise through the sequence of grids (from large to small), and identifies cells where the greater Q does not inundate a cell inundated by the lesser Q. It then sets these cells in the lesser Q grid to NA. The “trimmed” lesser grid then becomes the greater Q in the next pair of grids in the sequence. Once complete, this script eliminates all cases of a cell modulating between being inundated and non-inundated – once its Active, it stays Active for all larger flows.

