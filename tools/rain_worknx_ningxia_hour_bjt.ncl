;============================================================
; WORK_nx Ningxia hourly precipitation panels, BJT labels.
; Produces T13-T48 only: 36 hourly panels for a 6x6 overview.
;============================================================

load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"

function bjt_label(tstr:string, style:integer)
local yy, mm, dd, hh, mins, secs, units, utc_value, bjt_value, calendar
begin
  yy   = toint(str_get_cols(tstr, 0, 3))
  mm   = toint(str_get_cols(tstr, 5, 6))
  dd   = toint(str_get_cols(tstr, 8, 9))
  hh   = toint(str_get_cols(tstr, 11, 12))
  mins = toint(str_get_cols(tstr, 14, 15))
  secs = toint(str_get_cols(tstr, 17, 18))

  units = "hours since 1900-01-01 00:00:00"
  utc_value = cd_inv_calendar(yy, mm, dd, hh, mins, secs, units, 0)
  bjt_value = utc_value + 8.0
  bjt_value@units = units
  calendar = cd_calendar(bjt_value, 0)

  if (style.eq.1) then
    return sprinti("%0.4i", toint(calendar(0,0))) + sprinti("%0.2i", toint(calendar(0,1))) + sprinti("%0.2i", toint(calendar(0,2))) + sprinti("%0.2i", toint(calendar(0,3)))
  end if
  if (style.eq.2) then
    return sprinti("%0.2i", toint(calendar(0,1))) + "-" + sprinti("%0.2i", toint(calendar(0,2))) + " " + sprinti("%0.2i", toint(calendar(0,3))) + ":00"
  end if
  if (style.eq.3) then
    return sprinti("%0.4i", toint(calendar(0,0))) + sprinti("%0.2i", toint(calendar(0,1))) + sprinti("%0.2i", toint(calendar(0,2))) + "_" + sprinti("%0.2i", toint(calendar(0,3)))
  end if
  return sprinti("%0.2i", toint(calendar(0,3))) + ":00"
end

begin
  wrf_dir = getenv("WORK_NX_WRF_DIR")
  out_dir = getenv("WORK_NX_NINGXIA_PNG_DIR")
  province_shp_file = getenv("NINGXIA_PROVINCE_SHP_FILE")
  county_shp_file = getenv("NINGXIA_COUNTY_SHP_FILE")
  accum_hours_text = getenv("RAIN_ACCUM_HOURS")
  legacy_shp_file = getenv("NINGXIA_SHP_FILE")

  if (wrf_dir.eq."") then
    wrf_dir = "."
  end if
  if (out_dir.eq."") then
    out_dir = "worknx_ningxia_hourly_png"
  end if
  if (ismissing(province_shp_file)) then
    province_shp_file = ""
  end if
  if (ismissing(county_shp_file)) then
    county_shp_file = ""
  end if
  if (ismissing(accum_hours_text) .or. accum_hours_text.eq."") then
    accum_hours = 1
  else
    accum_hours = toint(accum_hours_text)
  end if
  if (accum_hours.lt.1) then
    accum_hours = 1
  end if
  if (ismissing(legacy_shp_file)) then
    legacy_shp_file = ""
  end if
  if (province_shp_file.eq."" .and. legacy_shp_file.ne."") then
    province_shp_file = legacy_shp_file
  end if

  system("mkdir -p " + out_dir)
  files = systemfunc("ls -1 " + wrf_dir + "/wrfout_d01_*")
  if (dimsizes(files).eq.0) then
    print("ERROR: no wrfout_d01 files in " + wrf_dir)
    exit
  end if

  ; Ningxia plus a narrow surrounding margin.
  lon_min = 104.0
  lon_max = 107.8
  lat_min = 35.0
  lat_max = 39.7
  ; Keep the exact hourly colorbar used by the Huan regional product.
  rain_levs = (/0.0, 1.5, 7.0, 15.0, 40.0, 50.0/)

  do ifile = 0, dimsizes(files)-1
    f = addfile(files(ifile), "r")
    times = wrf_user_getvar(f, "times", -1)
    ntimes = dimsizes(times)
    start_idx = 13
    end_idx = min((/48, ntimes - 1/))

    if (end_idx.lt.start_idx) then
      print("WARNING: fewer than T13 fields in " + files(ifile))
      delete(f)
      continue
    end if

    lat2d = f->XLAT(0,:,:)
    lon2d = f->XLONG(0,:,:)
    ; WORK_nx d01 is nearly regular over Ningxia.  Plot a compact local
    ; rectangular subset with one-dimensional axes: NCL 6.6.2 can crash when
    ; the whole 400x400 curvilinear field is supplied as sfXArray/sfYArray.
    nrows = dimsizes(lat2d(:,0))
    ncols = dimsizes(lon2d(0,:))
    mid_row = toint(nrows/2)
    mid_col = toint(ncols/2)
    row_ind = ind(lat2d(:,mid_col).ge.lat_min .and. lat2d(:,mid_col).le.lat_max)
    col_ind = ind(lon2d(mid_row,:).ge.lon_min .and. lon2d(mid_row,:).le.lon_max)
    row_start = toint(max((/0, min(row_ind)-2/)))
    row_end = toint(min((/nrows-1, max(row_ind)+2/)))
    col_start = toint(max((/0, min(col_ind)-2/)))
    col_end = toint(min((/ncols-1, max(col_ind)+2/)))
    lat_axis = lat2d(row_start:row_end,mid_col)
    lon_axis = lon2d(mid_row,col_start:col_end)
    rain_all = f->RAINNC + f->RAINC
    init_bjt = bjt_label(f@START_DATE, 3)

    if (accum_hours.eq.1) then
      first_end_idx = start_idx
    else
      first_end_idx = start_idx + accum_hours - 1
    end if
    do it = first_end_idx, end_idx, accum_hours
      accum_start_idx = it - accum_hours
      if (accum_hours.eq.1) then
        accum_start_idx = it - 1
      end if
      file_start = bjt_label(times(accum_start_idx), 1)
      file_end = bjt_label(times(it), 1)
      rain_h = rain_all(it,:,:) - rain_all(accum_start_idx,:,:)
      rain_region = rain_h(row_start:row_end,col_start:col_end)
      ; Put trace/zero rain below the first contour level. That is the white
      ; below-range class, while an all-missing panel triggers NO CONTOUR.
      rain_region = where(rain_region.lt.0.01, -1.0, rain_region)

      if (accum_hours.eq.1) then
        out_name = init_bjt + "_rain_hour_" + file_start + "-" + file_end + "_BJT"
      else
        out_name = init_bjt + "_combined_accum_" + sprinti("%0.2i",accum_hours) + "h_" + file_start + "-" + file_end + "_BJT_grid"
      end if
      wks = gsn_open_wks("png", out_dir + "/" + out_name)
      cmap = (/(/1.00,1.00,1.00/), (/0.00,0.00,0.00/), (/1.00,1.00,1.00/), \
               (/0.42,0.86,0.40/), (/0.25,0.72,0.25/), (/0.42,0.68,0.90/), \
               (/0.10,0.05,1.00/), (/0.92,0.00,0.92/), (/116.0/255,30.0/255,7.0/255/)/)
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
      res@cnNoDataLabelOn = False
      res@cnLevelSelectionMode = "ExplicitLevels"
      res@cnLevels = rain_levs
      res@cnFillColors = (/2,3,4,5,6,7/)
      res@cnConstFEnableFill = True
      res@cnConstFLabelOn = False
      res@cnMissingValFillColor = "white"
      res@cnFillDrawOrder = "PreDraw"
      ; Administrative boundaries are supplied by SHP overlays below. Do not
      ; draw the NCL default outline as it can duplicate or conflict with them.
      res@mpOutlineBoundarySets = "NoBoundaries"
      res@mpFillOn = False
      res@mpProjection = "CylindricalEquidistant"
      res@mpMinLonF = lon_min
      res@mpMaxLonF = lon_max
      res@mpMinLatF = lat_min
      res@mpMaxLatF = lat_max
      res@sfXArray = lon_axis
      res@sfYArray = lat_axis
      res@pmTickMarkDisplayMode = "Always"
      res@gsnMajorLonSpacing = 1.0
      res@gsnMajorLatSpacing = 1.0
      res@tmXMajorGrid = False
      res@tmYMajorGrid = False
      res@tmXMinorGrid = False
      res@tmYMinorGrid = False
      ; The precipitation palette has green at color index 1.  Explicitly use
      ; black for interface text so it never inherits a palette entry.
      res@tmXBLabelFont = "Times-Bold"
      res@tmXBLabelFontColor = "black"
      res@tmXBLabelFontHeightF = 0.025
      res@tmXBLabelFontThicknessF = 6
      res@tmYLLabelFont = "Times-Bold"
      res@tmYLLabelFontColor = "black"
      res@tmYLLabelFontHeightF = 0.025
      res@tmYLLabelFontThicknessF = 6
      res@tmBorderLineColor = "black"
      res@tmBorderThicknessF = 5
      if (accum_hours.gt.1) then
        res@tiMainString = sprinti("%0.2i",accum_hours) + " h accumulation " + bjt_label(times(accum_start_idx),2) + "-" + bjt_label(times(it),4)
        res@tiMainFont = "Times-Bold"
        res@tiMainFontThicknessF = 3.0
        res@tiMainFontHeightF = 0.04
        res@tiMainFontColor = "black"
      end if
      res@lbLabelFont = "Times-Bold"
      res@lbLabelFontThicknessF = 5.0
      res@lbLabelFontColor = "black"
      res@lbLabelBarOn = True
      res@lbOrientation = "Vertical"
      res@pmLabelBarDisplayMode = "Always"
      res@pmLabelBarSide = "Right"

      plot = gsn_csm_contour_map(wks, rain_region, res)
      if (county_shp_file.ne."" .and. fileexists(county_shp_file)) then
        county_shp_res = True
        county_shp_res@gsLineColor = "black"
        county_shp_res@gsLineThicknessF = 3.2
        county_shp_line = gsn_add_shapefile_polylines(wks, plot, county_shp_file, county_shp_res)
      end if
      if (province_shp_file.ne."" .and. fileexists(province_shp_file)) then
        province_shp_res = True
        province_shp_res@gsLineColor = "black"
        province_shp_res@gsLineThicknessF = 8.5
        province_shp_line = gsn_add_shapefile_polylines(wks, plot, province_shp_file, province_shp_res)
      end if
      draw(plot)
      frame(wks)
      delete([/plot, wks, rain_h, rain_region/])
    end do
    delete([/f, times, rain_all/])
  end do
end
