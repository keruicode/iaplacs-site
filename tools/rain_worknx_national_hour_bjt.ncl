;============================================================
; WORK_nx nationwide hourly precipitation panels, BJT labels.
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
  return sprinti("%0.4i", toint(calendar(0,0))) + sprinti("%0.2i", toint(calendar(0,1))) + sprinti("%0.2i", toint(calendar(0,2))) + "_" + sprinti("%0.2i", toint(calendar(0,3)))
end

begin
  wrf_dir = getenv("WORK_NX_WRF_DIR")
  out_dir = getenv("WORK_NX_NATIONAL_PNG_DIR")
  province_shp_file = getenv("WORK_NX_NATIONAL_PROVINCE_SHP_FILE")
  accum_hours_text = getenv("RAIN_ACCUM_HOURS")
  if (wrf_dir.eq."") then
    wrf_dir = "."
  end if
  if (out_dir.eq."") then
    out_dir = "worknx_national_hourly_png"
  end if
  if (ismissing(province_shp_file)) then
    province_shp_file = ""
  end if
  if (ismissing(accum_hours_text) .or. accum_hours_text.eq."") then
    accum_hours = 1
  else
    accum_hours = toint(accum_hours_text)
  end if
  if (accum_hours.lt.1) then
    accum_hours = 1
  end if

  system("mkdir -p " + out_dir)
  files = systemfunc("ls -1 " + wrf_dir + "/wrfout_d01_*")
  if (dimsizes(files).eq.0) then
    print("ERROR: no wrfout_d01 files in " + wrf_dir)
    exit
  end if

  lon_min = 72.0
  lon_max = 138.0
  lat_min = 16.0
  lat_max = 55.0
  ; These are geographic coordinates, not montage pixel positions.  The
  ; CylindricalEquidistant MapPlot maps them directly to its bottom/left axes.
  national_lon_ticks = (/75.0, 90.0, 105.0, 120.0, 135.0/)
  national_lon_labels = (/"75~S~o~N~E", "90~S~o~N~E", "105~S~o~N~E", \
                          "120~S~o~N~E", "135~S~o~N~E"/)
  national_lat_ticks = (/20.0, 30.0, 40.0, 50.0/)
  national_lat_labels = (/"20~S~o~N~N", "30~S~o~N~N", \
                          "40~S~o~N~N", "50~S~o~N~N"/)
  ; CMA hourly precipitation classes: no rain, 0-2.5, 2.5-5, 5-10,
  ; 10-25, 25-50, 50-100 and above 100 mm. Accumulations retain their
  ; existing operational palette.
  if (accum_hours.eq.1) then
    rain_levs = (/0.0, 2.5, 5.0, 10.0, 25.0, 50.0, 100.0/)
    fill_colors = (/2,3,4,5,6,7,8,9/)
  else
    rain_levs = (/0.0, 0.1, 10.0, 25.0, 50.0, 100.0, 250.0/)
    fill_colors = (/2,2,3,4,5,6,7,8/)
  end if
  wks_type = "png"
  wks_type@wkWidth = 1800
  wks_type@wkHeight = 1800

  do ifile = 0, dimsizes(files)-1
    f = addfile(files(ifile), "r")
    times = wrf_user_getvar(f, "times", -1)
    ntimes = dimsizes(times)
    start_idx = 13
    end_idx = min((/48, ntimes - 1/))
    if (accum_hours.gt.1) then
      ; A cumulative interval must start after the first 12 hours of WRF
      ; spin-up.  Iterate hourly below, then retain only BJT 08/20 endpoints.
      start_idx = 12 + accum_hours
    end if
    if (end_idx.lt.start_idx) then
      print("WARNING: insufficient fields for requested precipitation product in " + files(ifile))
      delete(f)
      continue
    end if

    lat2d = f->XLAT(0,:,:)
    lon2d = f->XLONG(0,:,:)
    nrows = dimsizes(lat2d(:,0))
    ncols = dimsizes(lon2d(0,:))
    lat_axis = lat2d(:,toint(ncols/2))
    lon_axis = lon2d(toint(nrows/2),:)
    rain_all = f->RAINNC + f->RAINC
    init_bjt = bjt_label(f@START_DATE, 3)

    do it = start_idx, end_idx
      accum_start_idx = it - accum_hours
      if (accum_hours.eq.1) then
        accum_start_idx = it - 1
      end if
      file_start = bjt_label(times(accum_start_idx), 1)
      file_end = bjt_label(times(it), 1)
      panel_title = str_get_cols(file_start, 4, 5) + "-" + \
                    str_get_cols(file_start, 6, 7) + " " + \
                    str_get_cols(file_start, 8, 9) + ":00-" + \
                    str_get_cols(file_end, 8, 9) + ":00"
      end_hour = toint(str_get_cols(file_end, 8, 9))
      ; 12 h: 08-20 or 20-08 BJT. 24 h: 08-08 or 20-20 BJT.  Both
      ; tests are represented by the corresponding ending hour.
      if (accum_hours.gt.1 .and. end_hour.ne.8 .and. end_hour.ne.20) then
        continue
      end if
      rain_h = rain_all(it,:,:) - rain_all(accum_start_idx,:,:)
      ; Put trace/zero rain below the first contour level. That is the white
      ; below-range class, while an all-missing panel triggers NO CONTOUR.
      rain_h = where(rain_h.lt.0.01, -1.0, rain_h)

      if (accum_hours.eq.1) then
        out_name = init_bjt + "_national_rain_hour_" + file_start + "-" + file_end + "_BJT"
      else
        out_name = init_bjt + "_national_accum_" + sprinti("%0.2i",accum_hours) + "h_" + file_start + "-" + file_end + "_BJT"
      end if
      wks = gsn_open_wks(wks_type, out_dir + "/" + out_name)
      if (accum_hours.eq.1) then
        cmap = (/(/1.00,1.00,1.00/), (/0.00,0.00,0.00/), (/1.00,1.00,1.00/), \
                 (/0.86,0.97,0.82/), (/0.60,0.91,0.52/), (/0.31,0.76,0.29/), \
                 (/0.12,0.62,0.18/), (/0.33,0.65,0.87/), (/0.00,0.00,0.86/), \
                 (/0.86,0.00,0.78/)/)
      else
        cmap = (/(/1.00,1.00,1.00/), (/0.00,0.00,0.00/), (/1.00,1.00,1.00/), \
                 (/186.0/255,244.0/255,168.0/255/), (/84.0/255,199.0/255,104.0/255/), \
                 (/96.0/255,174.0/255,234.0/255/), (/23.0/255,39.0/255,230.0/255/), \
                 (/236.0/255,55.0/255,231.0/255/), (/122.0/255,11.0/255,120.0/255/)/)
      end if
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
      res@cnFillColors = fill_colors
      res@cnConstFEnableFill = True
      res@cnConstFLabelOn = False
      res@cnMissingValFillColor = "white"
      res@cnFillDrawOrder = "PreDraw"
      res@mpProjection = "CylindricalEquidistant"
      res@mpDataBaseVersion = "MediumRes"
      ; The China provincial shapefile below is the sole boundary source for
      ; this product. Do not draw surrounding-country borders or a world map.
      res@mpOutlineBoundarySets = "NoBoundaries"
      res@mpFillOn = False
      res@mpMinLonF = lon_min
      res@mpMaxLonF = lon_max
      res@mpMinLatF = lat_min
      res@mpMaxLatF = lat_max
      res@sfXArray = lon_axis
      res@sfYArray = lat_axis
      ; Native NCL tickmarks for a cylindrical-equidistant map.  Explicit
      ; geographic values prevent MapPlot's built-in automatic 5-degree ticks
      ; from replacing the intended labelled intervals after montage trimming.
      ; This remains map-coordinate rendering, not manual image annotation.
      res@tmXBMode = "Explicit"
      res@tmXBValues = national_lon_ticks
      res@tmXBLabels = national_lon_labels
      res@tmYLMode = "Explicit"
      res@tmYLValues = national_lat_ticks
      res@tmYLLabels = national_lat_labels
      ; Retain only labelled major ticks on the bottom and left axes.
      res@tmXTOn = False
      res@tmYROn = False
      res@tmXBMinorOn = False
      res@tmXTMinorOn = False
      res@tmYLMinorOn = False
      res@tmYRMinorOn = False
      res@tmXMajorGrid = False
      res@tmYMajorGrid = False
      res@tmXMinorGrid = False
      res@tmYMinorGrid = False
      ; Explicit outward lengths keep the geographic major ticks visible after
      ; each panel is trimmed and placed in the 6x6 montage.
      res@tmXBMajorLengthF = 0.018
      res@tmXBMajorOutwardLengthF = 0.012
      res@tmXBMajorThicknessF = 2.2
      res@tmYLMajorLengthF = 0.018
      res@tmYLMajorOutwardLengthF = 0.012
      res@tmYLMajorThicknessF = 2.2
      res@tmXBLabelFont = "Times-Bold"
      res@tmXBLabelFontColor = "black"
      res@tmXBLabelFontHeightF = 0.028
      res@tmXBLabelFontThicknessF = 2.2
      ; Match NCL's cylindrical-map tickmark example: degree labels are
      ; aligned by their baseline and offset from the newly visible ticks.
      res@tmXBLabelJust = "BottomCenter"
      res@tmXBLabelDeltaF = 1.0
      res@tmXBLabelsOn = True
      res@tmYLLabelsOn = True
      res@tmYLLabelFont = "Times-Bold"
      res@tmYLLabelFontColor = "black"
      res@tmYLLabelFontHeightF = 0.028
      res@tmYLLabelFontThicknessF = 2.2
      res@tmYLLabelDeltaF = -0.15
      res@tmBorderLineColor = "black"
      res@tmBorderThicknessF = 6
      ; Align the wide China map at the top of the canvas.  Hourly panels
      ; carry their own valid-time title; accumulated products receive one
      ; complete interval title from the publishing wrapper instead.
      res@vpXF = 0.13
      res@vpYF = 0.82
      res@vpWidthF = 0.70
      res@vpHeightF = 0.60
      if (accum_hours.eq.1) then
        res@tiMainString = panel_title
        res@tiMainFont = "Times-Bold"
        res@tiMainFontHeightF = 0.035
        res@tiMainFontThicknessF = 3.0
        res@tiMainFontColor = "black"
        res@tiMainOffsetYF = -0.012
      end if
      ; NCL 6.3 may automatically stride a vertical label bar and hide every
      ; other cumulative threshold.  Keep every operational boundary visible.
      if (accum_hours.gt.1) then
        res@cnExplicitLabelBarLabelsOn = True
        res@lbLabelStrings = (/"0", "0.1", "10", "25", "50", "100", "250"/)
        res@lbLabelAlignment = "InteriorEdges"
        res@lbAutoManage = False
        res@lbLabelAutoStride = False
        res@lbLabelStride = 1
      end if
      res@lbLabelFont = "Times-Bold"
      res@lbLabelFontColor = "black"
      if (accum_hours.gt.1) then
        res@lbLabelFontHeightF = 0.025
        res@lbLabelFontThicknessF = 5.0
      else
        res@lbLabelFontHeightF = 0.034
        res@lbLabelFontThicknessF = 8
      end if
      res@lbLabelBarOn = True
      res@lbOrientation = "Vertical"
      res@pmLabelBarDisplayMode = "Always"
      res@pmLabelBarSide = "Right"

      plot = gsn_csm_contour_map(wks, rain_h, res)
      if (province_shp_file.ne."" .and. fileexists(province_shp_file)) then
        province_shp_res = True
        province_shp_res@gsLineColor = "black"
        province_shp_res@gsLineThicknessF = 8.0
        province_shp_line = gsn_add_shapefile_polylines(wks, plot, province_shp_file, province_shp_res)
      end if
      draw(plot)
      frame(wks)
      delete([/plot, wks, rain_h/])
    end do
    delete([/f, times, rain_all/])
  end do
end
