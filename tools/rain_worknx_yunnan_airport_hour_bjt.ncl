;============================================================
; WORK_yn Yunnan airport hourly precipitation panels, BJT labels.
; Produces 36 hourly panels for a 6x6 overview.
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
  wrf_dir = getenv("WORK_YN_WRF_DIR")
  out_dir = getenv("WORK_YN_YUNNAN_AIRPORT_PNG_DIR")
  province_shp_file = getenv("YUNNAN_PROVINCE_SHP_FILE")

  if (wrf_dir.eq."") then
    wrf_dir = getenv("WORK_NX_WRF_DIR")
  end if
  if (out_dir.eq."") then
    out_dir = getenv("WORK_NX_YUNNAN_AIRPORT_PNG_DIR")
  end if
  if (wrf_dir.eq."") then
    wrf_dir = "."
  end if
  if (out_dir.eq."") then
    out_dir = "worknx_yunnan_airport_hourly_png"
  end if
  if (ismissing(province_shp_file)) then
    province_shp_file = ""
  end if

  system("mkdir -p " + out_dir)
  files = systemfunc("ls -1 " + wrf_dir + "/wrfout_d01_*")
  if (dimsizes(files).eq.0) then
    print("ERROR: no wrfout_d01 files in " + wrf_dir)
    exit
  end if

  ; Yunnan bounding box with a small margin.
  lon_min = 97.0
  lon_max = 106.7
  lat_min = 21.0
  lat_max = 29.7

  airport_lons = (/98.533300, 100.762222, 99.783889/)
  airport_lats = (/24.400000, 21.973611, 22.417778/)
  plane_scale_outer = 0.185
  plane_scale_inner = 0.145

  ; Keep the precipitation thresholds and palette identical to the regional products.
  rain_levs = (/0, 1.5, 7.0, 15.0, 40.0, 50.0/)

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
      file_start = bjt_label(times(it-1), 1)
      file_end = bjt_label(times(it), 1)
      rain_h = rain_all(it,:,:) - rain_all(it-1,:,:)
      rain_h@_FillValue = -9999.0
      rain_h = where(rain_h.lt.0.01, rain_h@_FillValue, rain_h)
      rain_h@lat2d = lat2d
      rain_h@lon2d = lon2d

      wks = gsn_open_wks("png", out_dir + "/" + init_bjt + "_yunnan_airport_rain_hour_" + file_start + "-" + file_end + "_BJT")
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
      res@tmBorderThicknessF = 3
      res@lbLabelFontColor = "black"
      res@lbLabelBarOn = True
      res@lbOrientation = "Vertical"
      res@pmLabelBarDisplayMode = "Always"
      res@pmLabelBarSide = "Right"

      plot = gsn_csm_contour_map(wks, rain_h, res)

      if (province_shp_file.ne."" .and. fileexists(province_shp_file)) then
        province_shp_res = True
        province_shp_res@gsLineColor = "black"
        province_shp_res@gsLineThicknessF = 2.5
        province_shp_line = gsn_add_shapefile_polylines(wks, plot, province_shp_file, province_shp_res)
      end if

      plane_back = new(3, graphic)
      plane_face = new(3, graphic)
      plane_x_template = (/1.8, -1.1, -0.35, -1.35, 0.1, -1.1, 1.8/)
      plane_y_template = (/0.0, 0.34, 0.08, 0.86, 0.0, -0.34, 0.0/)

      plane_back_res = True
      plane_back_res@gsFillColor = "white"
      plane_back_res@gsEdgesOn = False
      plane_face_res = True
      plane_face_res@gsFillColor = "black"
      plane_face_res@gsEdgesOn = False

      do ia = 0, 2
        plane_x_outer = airport_lons(ia) + plane_scale_outer * plane_x_template
        plane_y_outer = airport_lats(ia) + plane_scale_outer * plane_y_template
        plane_x_inner = airport_lons(ia) + plane_scale_inner * plane_x_template
        plane_y_inner = airport_lats(ia) + plane_scale_inner * plane_y_template
        plane_back(ia) = gsn_add_polygon(wks, plot, plane_x_outer, plane_y_outer, plane_back_res)
        plane_face(ia) = gsn_add_polygon(wks, plot, plane_x_inner, plane_y_inner, plane_face_res)
      end do

      draw(plot)
      frame(wks)
      delete([/plot, wks, rain_h/])
    end do
    delete([/f, times, rain_all/])
  end do
end
