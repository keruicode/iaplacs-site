;============================================================
; Shangrao WRF hourly precipitation panels, BJT labels.
; Adds province and Shangrao city/county SHP overlays.
;============================================================

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"

function get_bjt_info(tstr:string, format:integer)
local yy, mm, dd, hh, mins, secs, units, time_val, bjt_val, bjt_arr
begin
  yy   = toint(str_get_cols(tstr, 0, 3))
  mm   = toint(str_get_cols(tstr, 5, 6))
  dd   = toint(str_get_cols(tstr, 8, 9))
  hh   = toint(str_get_cols(tstr, 11, 12))
  mins = toint(str_get_cols(tstr, 14, 15))
  secs = toint(str_get_cols(tstr, 17, 18))

  units    = "hours since 1900-01-01 00:00:00"
  time_val = cd_inv_calendar(yy, mm, dd, hh, mins, secs, units, 0)
  bjt_val  = time_val + 8.0
  bjt_val@units = units
  bjt_arr = cd_calendar(bjt_val, 0)

  if (format .eq. 1) then
    return sprinti("%0.4i", toint(bjt_arr(0,0))) + sprinti("%0.2i", toint(bjt_arr(0,1))) + sprinti("%0.2i", toint(bjt_arr(0,2))) + sprinti("%0.2i", toint(bjt_arr(0,3)))
  end if
  if (format .eq. 2) then
    return sprinti("%0.2i", toint(bjt_arr(0,1))) + "-" + sprinti("%0.2i", toint(bjt_arr(0,2))) + " " + sprinti("%0.2i", toint(bjt_arr(0,3))) + ":00"
  end if
  if (format .eq. 3) then
    return sprinti("%0.4i", toint(bjt_arr(0,0))) + sprinti("%0.2i", toint(bjt_arr(0,1))) + sprinti("%0.2i", toint(bjt_arr(0,2))) + "_" + sprinti("%0.2i", toint(bjt_arr(0,3)))
  end if
  if (format .eq. 4) then
    return sprinti("%0.2i", toint(bjt_arr(0,3))) + ":00"
  end if
  return ""
end

begin
  wrf_dir = getenv("SHANGRAO_WRF_DIR")
  out_dir = getenv("SHANGRAO_PNG_DIR")
  province_shp_file = getenv("SHANGRAO_PROVINCE_SHP_FILE")
  county_shp_file = getenv("SHANGRAO_COUNTY_SHP_FILE")
  legacy_shp_file = getenv("SHANGRAO_SHP_FILE")

  if (ismissing(wrf_dir)) then
    wrf_dir = ""
  end if
  if (ismissing(out_dir)) then
    out_dir = ""
  end if
  if (ismissing(province_shp_file)) then
    province_shp_file = ""
  end if
  if (ismissing(county_shp_file)) then
    county_shp_file = ""
  end if
  if (ismissing(legacy_shp_file)) then
    legacy_shp_file = ""
  end if

  if (wrf_dir.eq."") then
    wrf_dir = "."
  end if
  if (out_dir.eq."") then
    out_dir = "wrf_hourly_png"
  end if
  if (province_shp_file.eq."" .and. legacy_shp_file.ne."") then
    province_shp_file = legacy_shp_file
  end if
  if (province_shp_file.eq."") then
    province_shp_file = "./SHP/省界_region.shp"
  end if
  if (county_shp_file.eq."") then
    county_shp_file = "./SHP/shangrao_city_county.shp"
  end if

  files = systemfunc("ls -1 " + wrf_dir + "/wrfout_d01_*")
  if (dimsizes(files).eq.0) then
    print("ERROR: no wrfout_d01 files in " + wrf_dir)
    exit
  end if
  system("mkdir -p " + out_dir)

  lon_min = 112.0
  lon_max = 120.0
  lat_min = 24.0
  lat_max = 32.0
  rain_levs = (/0, 1.5, 7.0, 15.0, 40.0, 50.0/)

  do ifile = 0, dimsizes(files)-1
    print("processing file: " + files(ifile))
    f = addfile(files(ifile), "r")

    times = wrf_user_getvar(f, "times", -1)
    ntimes = dimsizes(times)

    lat2d = f->XLAT(0,:,:)
    lon2d = f->XLONG(0,:,:)
    rain_all = f->RAINNC + f->RAINC

    start_date = f@START_DATE
    init_bjt_str = get_bjt_info(start_date, 3)

    start_idx = 13
    if (ntimes .le. start_idx) then
      print("WARNING: fewer than T13 fields, skipped")
      delete([/f, times, rain_all/])
      continue
    end if

    do it = start_idx, ntimes-1
      bjt_start_title = get_bjt_info(times(it-1), 2)
      bjt_end_title   = get_bjt_info(times(it), 4)
      label           = bjt_start_title + "-" + bjt_end_title

      bjt_start_file  = get_bjt_info(times(it-1), 1)
      bjt_end_file    = get_bjt_info(times(it), 1)

      rain_h = rain_all(it,:,:) - rain_all(it-1,:,:)
      rain_h@_FillValue = -9999.0
      rain_h = where(rain_h.lt.0.01, rain_h@_FillValue, rain_h)
      rain_h@lat2d = lat2d
      rain_h@lon2d = lon2d

      out_name = init_bjt_str + "_rain_hour_" + bjt_start_file + "-" + bjt_end_file + "_BJT"
      print("drawing: " + label)
      print("output: " + out_name + ".png")

      wks = gsn_open_wks("png", out_dir + "/" + out_name)
      cmap = (/(/1.00,1.00,1.00/), (/0.00,0.00,0.00/), (/1.00,1.00,1.00/), \
               (/0.42,0.86,0.40/), (/0.25,0.72,0.25/), (/0.42,0.68,0.90/), \
               (/0.10,0.05,1.00/), (/0.92,0.00,0.92/), (/116.0/255, 30.0/255, 7.0/255/)/)
      gsn_define_colormap(wks, cmap)

      res = True
      res@gsnDraw = False
      res@gsnFrame = False
      res@gsnMaximize = True
      res@gsnAddCyclic = False
      res@cnFillOn = True
      res@cnLinesOn = False
      res@cnLineLabelsOn = False
      res@cnInfoLabelOn = False
      res@cnLevelSelectionMode = "ExplicitLevels"
      res@cnLevels = rain_levs
      res@cnFillColors = (/2,3,4,5,6,7/)
      res@cnMissingValFillColor = "white"
      res@cnFillDrawOrder = "PreDraw"
      res@mpOutlineBoundarySets = "NoBoundaries"
      res@mpFillOn = False
      res@mpProjection = "CylindricalEquidistant"
      res@mpMinLonF = lon_min
      res@mpMaxLonF = lon_max
      res@mpMinLatF = lat_min
      res@mpMaxLatF = lat_max
      res@pmTickMarkDisplayMode = "Always"
      res@gsnMajorLonSpacing = 2.0
      res@gsnMajorLatSpacing = 2.0
      res@tmXBLabelFontColor = "black"
      res@tmXBLabelFontHeightF = 0.025
      res@tmXBLabelFontThicknessF = 4
      res@tmYLLabelFontColor = "black"
      res@tmYLLabelFontHeightF = 0.025
      res@tmYLLabelFontThicknessF = 4
      res@tmBorderLineColor = "black"
      res@tmBorderThicknessF = 6
      res@vpXF = 0.16
      res@vpWidthF = 0.62
      res@vpYF = 0.82
      res@vpHeightF = 0.62
      res@tiMainString = label
      res@tiMainFontHeightF = 0.065
      res@tiMainFont = 22
      res@tiMainFontColor = "black"
      res@tiMainOffsetYF = -0.018
      res@lbLabelFontColor = "black"
      res@lbLabelBarOn = True
      res@lbOrientation = "Vertical"
      res@pmLabelBarDisplayMode = "Always"
      res@pmLabelBarSide = "Right"

      plot = gsn_csm_contour_map(wks, rain_h, res)

      if (county_shp_file.ne."" .and. fileexists(county_shp_file)) then
        county_shp_res = True
        county_shp_res@gsLineColor = "black"
        county_shp_res@gsLineThicknessF = 2.8
        county_shp_line = gsn_add_shapefile_polylines(wks, plot, county_shp_file, county_shp_res)
      end if
      if (province_shp_file.ne."" .and. fileexists(province_shp_file)) then
        province_shp_res = True
        province_shp_res@gsLineColor = "black"
        province_shp_res@gsLineThicknessF = 4
        province_shp_line = gsn_add_shapefile_polylines(wks, plot, province_shp_file, province_shp_res)
      end if

      draw(plot)
      frame(wks)

      delete([/plot, wks, rain_h/])
    end do
    delete([/f, times, rain_all/])
  end do
end
