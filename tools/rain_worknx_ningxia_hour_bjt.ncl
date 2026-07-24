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
  ; Use the same hourly thresholds as the WORK_nx nationwide product.  A
  ; zero lower bound colored trace accumulation across the entire regional
  ; domain even when the nationwide product correctly remained white.
  rain_levs = (/0.1, 1.0, 2.5, 5.0, 10.0, 20.0, 30.0, 50.0/)

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
      ; WORK_nx accumulation fields do not carry a missing-value attribute.
      ; Define one before masking trace precipitation so NCL does not return an
      ; attribute-reference error after every hourly panel.
      rain_h@_FillValue = -9999.0
      rain_h = where(rain_h.lt.0.01, rain_h@_FillValue, rain_h)
      rain_h@lat2d = lat2d
      rain_h@lon2d = lon2d

      wks = gsn_open_wks("png", out_dir + "/" + init_bjt + "_rain_hour_" + file_start + "-" + file_end + "_BJT")
      cmap = (/(/1.00,1.00,1.00/), (/0.00,0.00,0.00/), (/1.00,1.00,1.00/), \
               (/0.65,0.94,0.57/), (/0.18,0.73,0.22/), (/0.35,0.68,0.90/), \
               (/0.10,0.05,1.00/), (/0.92,0.00,0.92/), (/0.50,0.05,0.20/), \
               (/0.45,0.05,0.00/)/)
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
      res@cnFillColors = (/2,3,4,5,6,7,8,9,9/)
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
      ; XLAT/XLONG are two-dimensional WRF coordinates.  Set the scalar
      ; field arrays explicitly so NCL clips actual Ningxia grid cells rather
      ; than treating the 400x400 field as a regular index-space map.
      res@sfXArray = lon2d
      res@sfYArray = lat2d
      res@pmTickMarkDisplayMode = "Always"
      res@gsnMajorLonSpacing = 1.0
      res@gsnMajorLatSpacing = 1.0
      res@tmXMajorGrid = False
      res@tmYMajorGrid = False
      res@tmXMinorGrid = False
      res@tmYMinorGrid = False
      ; The precipitation palette has green at color index 1.  Explicitly use
      ; black for interface text so it never inherits a palette entry.
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
      if (county_shp_file.ne."" .and. fileexists(county_shp_file)) then
        county_shp_res = True
        county_shp_res@gsLineColor = "black"
        county_shp_res@gsLineThicknessF = 1.4
        county_shp_line = gsn_add_shapefile_polylines(wks, plot, county_shp_file, county_shp_res)
      end if
      if (province_shp_file.ne."" .and. fileexists(province_shp_file)) then
        province_shp_res = True
        province_shp_res@gsLineColor = "black"
        province_shp_res@gsLineThicknessF = 3
        province_shp_line = gsn_add_shapefile_polylines(wks, plot, province_shp_file, province_shp_res)
      end if
      draw(plot)
      frame(wks)
      delete([/plot, wks, rain_h/])
    end do
    delete([/f, times, rain_all/])
  end do
end
