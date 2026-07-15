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
  shp_file = getenv("NINGXIA_SHP_FILE")

  if (wrf_dir.eq."") then
    wrf_dir = "."
  end if
  if (out_dir.eq."") then
    out_dir = "worknx_ningxia_hourly_png"
  end if
  if (ismissing(shp_file)) then
    shp_file = ""
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
  rain_levs = (/0, 0.1, 2.0, 5.0, 10.0, 25.0, 50.0/)

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
    rain_all = f->RAINNC + f->RAINC
    init_bjt = bjt_label(f@START_DATE, 3)

    do it = start_idx, end_idx
      label = bjt_label(times(it-1), 2) + "-" + bjt_label(times(it), 4)
      file_start = bjt_label(times(it-1), 1)
      file_end = bjt_label(times(it), 1)
      rain_h = rain_all(it,:,:) - rain_all(it-1,:,:)
      ; WORK_nx accumulation fields do not carry a missing-value attribute.
      ; Define one before masking trace precipitation so NCL does not return an
      ; attribute-reference error after every hourly panel.
      rain_h@_FillValue = -9999.0
      rain_h = where(rain_h.lt.0.01, rain_h@_FillValue, rain_h)
      rain_h@lat2d = lat2d
      rain_h@lon2d = lon2d

      wks = gsn_open_wks("png", out_dir + "/" + init_bjt + "_rain_hour_" + file_start + "-" + file_end + "_BJT")
      cmap = (/(/1.00,1.00,1.00/), (/0.35,0.78,0.32/), (/0.18,0.62,0.20/), (/0.25,0.60,0.92/), (/0.08,0.10,0.90/), (/0.88,0.00,0.84/), (/0.55,0.00,0.00/), (/0.35,0.00,0.00/)/)
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
      res@cnFillColors = (/0,1,2,3,4,5,6/)
      res@cnMissingValFillColor = "white"
      res@cnFillDrawOrder = "PreDraw"
      res@mpOutlineBoundarySets = "National"
      res@mpFillOn = False
      res@mpProjection = "CylindricalEquidistant"
      res@mpMinLonF = lon_min
      res@mpMaxLonF = lon_max
      res@mpMinLatF = lat_min
      res@mpMaxLatF = lat_max
      res@pmTickMarkDisplayMode = "Always"
      res@gsnMajorLonSpacing = 1.0
      res@gsnMajorLatSpacing = 1.0
      res@tmXBLabelFontHeightF = 0.025
      res@tmYLLabelFontHeightF = 0.025
      res@tmBorderThicknessF = 3
      res@tiMainString = "Ningxia region " + label
      res@tiMainFontHeightF = 0.050
      res@lbLabelBarOn = True
      res@lbOrientation = "Vertical"
      res@pmLabelBarDisplayMode = "Always"
      res@pmLabelBarSide = "Right"

      plot = gsn_csm_contour_map(wks, rain_h, res)
      if (shp_file.ne."" .and. fileexists(shp_file)) then
        shp_res = True
        shp_res@gsLineColor = "black"
        shp_res@gsLineThicknessF = 3
        shp_line = gsn_add_shapefile_polylines(wks, plot, shp_file, shp_res)
      end if
      draw(plot)
      frame(wks)
      delete([/plot, wks, rain_h/])
    end do
    delete([/f, times, rain_all/])
  end do
end
