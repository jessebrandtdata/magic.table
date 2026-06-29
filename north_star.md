# North Star — GsheetGenie

The problem with doing everything with code is that spreadsheet users may want the formulas relating numbers expressed in the google sheet!

So this is a dynamic sheet generator. Want to work in R or Python but want your output to be a google sheet with the raw data and any derived data constructed with a formula?

Should be as much like just working with a data frame as we can make it. Basically. you can send a base data frame or tibble or whatever to gsheet as is. but once you make it a (let's call it magic.table, for the moment). (but like should we inherit from tibble). then anything you do to it after that is a recorded computation. and either a computation is expressed as a gsheet formula or! or! there's a reference to an R function! which is from the closure. and that is a column you can include in the gsheet, i would say default in another sheet, but optionally in the same sheet or not in the sheet at all or various ways of expressing we can experiment with

But like the thing to be exported to a gsheet is just an R object. and it has a function that sends it to the gsheet it has a connection to - which is just a little bit of data stored in the object. and it can poll the gsheet to see if it has changed and uh warn and by default not overwrite, not sure of exact behavior.

## magic.table

a reusable table object based on tibble that records computations, can compare to synced external table, may have other functions: this is our magic table.