; Output DBZ_MAX to the explicit target file; source contains one checked time.
begin
  f = addfile(source,"r")
  p = todouble(f->P) + todouble(f->PB)
  tk = wrf_tk(p,todouble(f->T) + 300.d0)
  z = wrf_dbz(p,tk,todouble(f->QVAPOR),todouble(f->QRAIN),todouble(f->QSNOW),todouble(f->QGRAUP),0,0)
  composite = dim_max_n(z,0)
  composite!0 = "south_north"
  composite!1 = "west_east"
  composite@units = "dBZ"
  setfileoption("nc","Format","NetCDF4Classic")
  out = addfile(target,"c")
  out->DBZ_MAX = composite
  out@method = "NCL wrf_dbz ivarint=0 iliqskin=0; vertical maximum"
end
