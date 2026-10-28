# Lincang airport

The Yunnan profile includes Lincang/Boshang (LNJ/ZPLC) as `lincang_boshang`.
Plot and station extraction coordinates: 23.738333 N, 100.022500 E.
Source: Yunnan Airport Group's 2023 first short-term financing prospectus,
table 5-31, printed page 102: 23 degrees 44 minutes 18 seconds N,
100 degrees 01 minutes 21 seconds E.
https://pdf.dfcfw.com/pdf/H2_AN202303151584279897_1.pdf

These are the operator-disclosed location coordinates for weather visualization,
not a substitute for current certified aeronautical navigation data.

Deploy the NCL regional marker list, precipitation extractor, aviation renderer
and catalog builder together. The existing d02 preference remains unchanged.
Rerender the latest completed Yunnan run through the existing locked publisher;
future runs use the same scripts. Do not alter model files under zhoubj.

Deploy `cloud/airport-ratings-fc/dist/airport-ratings-fc.zip` to the existing
Hong Kong `airport-ratings` function. Keep its role, HTTP trigger, environment
and rating prefix unchanged. Existing three-airport ratings are preserved.
The frontend disables an airport's rating buttons until GET returns its key,
so partial deployment cannot submit unsupported ratings.
