library(sf)
library(dplyr)
library(ggplot2)
library(tmap)
library(tidyr)

certs_dom = readRDS("../inputdata/epc/epc_domestic_clean.Rds")
scot_dom = readRDS("../inputdata/epc/epc_scotland_domestic_clean.Rds")

bounds = read_sf("../build/data/GB_LSOA21_for_plots.gpkg")
islandBox = read_sf("../build/data/island_boxes.gpkg")
borders = bounds[bounds$hectares > 2000,]

names(certs_dom)[!names(certs_dom) %in% names(scot_dom)]
names(scot_dom)[!names(scot_dom) %in% names(certs_dom)]

certs_dom = certs_dom[,names(scot_dom)]
dom_all = rbind(certs_dom, scot_dom)

#rm(certs_nondom, scot_nondom, certs_dom, scot_dom)

# Clean up for publication
dom_all = dom_all[,c("UPRN","CURRENT_ENERGY_RATING","CURRENT_ENERGY_EFFICIENCY",
                   "POTENTIAL_ENERGY_EFFICIENCY","INSPECTION_DATE","geometry")]

dom_all$year = lubridate::year(lubridate::ymd(dom_all$INSPECTION_DATE))
dom_all$INSPECTION_DATE  = NULL

dom_all$CURRENT_ENERGY_RATING[!dom_all$CURRENT_ENERGY_RATING %in% c("A","B","C","D","E","F","G")] = NA

area_classifications_11_21 = readRDS("../build/_targets/objects/area_classifications_11_21")

cols = c("Cosmopolitan student neighbourhoods" ='#955123',
         "Ageing rural neighbourhoods" ='#007f42',
         "Prospering countryside life" ='#3ea456',
         "Remoter communities" ='#8aca8e',
         "Rural traits" ='#cfe8d1',
         "Achieving neighbourhoods" ='#00498d',
         "Asian traits" ='#2967ad',
         "Highly qualified professionals" ='#7b99c7',
         "Households in terraces and flats" ='#b9c8e1',
         "Challenged white communities" ='#e3ac20',
         "Constrained renters" ='#edca1a',
         "Hampered neighbourhoods" ='#f6e896',
         "Hard-pressed flat dwellers" ='#fcf5d8',
         "Ageing urban communities" ='#e64c2b',
         "Aspiring urban households" ='#ec773c',
         "Comfortable neighbourhoods" ='#faa460',
         "Endeavouring social renters" ='#fcc9a0',
         "Primary sector workers" ='#fee4ce',
         "Inner city cosmopolitan" = '#f79ff0',
         "Urban cultural mix" ='#6a339a',
         "Young ethnic communities" ='#9f84bd',
         "Affluent communities" ='#576362',
         "Ageing suburbanites" ='#a1a2a1',
         "Comfortable suburbia" ='#e5e4e3')

area_classifications_11_21 = area_classifications_11_21[c("LSOA21CD","lsoa_class_name")]
area_classifications_11_21$lsoa_class_name = factor(area_classifications_11_21$lsoa_class_name,
                                                    levels = names(cols))


lsoa = readRDS("../build/_targets/objects/bounds_lsoa_GB_full")
lsoa = left_join(lsoa, area_classifications_11_21, by = "LSOA21CD")

dom_all = st_transform(dom_all, 27700)

dom_all = st_join(dom_all, lsoa)
summary(is.na(dom_all$lsoa_class_name))

dom_summary = dom_all |>
  st_drop_geometry() |>
  group_by(lsoa_class_name, year) |>
  summarise(median_ee = median(CURRENT_ENERGY_EFFICIENCY, na.rm = TRUE),
            mean_ee = mean(CURRENT_ENERGY_EFFICIENCY, na.rm = TRUE))

dom_summary = dom_summary[dom_summary$year >= 2010,]
dom_summary = dom_summary[dom_summary$year <= 2026,]
dom_summary = dom_summary[!is.na(dom_summary$lsoa_class_name),]
saveRDS(dom_summary,"dom_epec_rating_over_time.Rds")




oac_plot = function(
    var  = dom_elec_kgco2e_percap,
    name = "Per person Electricty Emissions",
    dat  = lsoa_emissions_summary,
    xlims = c(min(dat$year), max(dat$year))
){

  # wrap legend labels to ~15 characters
  wrapped_labels <- stringr::str_wrap(unique(dat$lsoa_class_name), width = 20)
  names(wrapped_labels) <- unique(dat$lsoa_class_name)

  # Reorder legend by y-value at the final year (top to bottom)
  max_year <- max(dat$year, na.rm = TRUE)
  final_year_data <- dat %>%
    filter(year == max_year) %>%
    arrange(desc({{var}}))
  
  legend_order <- final_year_data$lsoa_class_name
  dat$lsoa_class_name <- factor(dat$lsoa_class_name, levels = legend_order)

  plot = ggplot(dat) +
    geom_line(aes(x = year,
                  y = {{var}},
                  colour = lsoa_class_name),
              linewidth = 1) +
    ylab(name) +
    xlab("Year") +
    scale_x_continuous(
      breaks  = seq(xlims[1], xlims[2], 2),
      expand  = c(0, 0),
      limits  = c(xlims[1], xlims[2])
    ) +
    scale_y_continuous(
      expand  = c(0, 0),
      limits  = c(50, 75)
    ) +
    guides(
      color = guide_legend(
        title = "Area classification",
        ncol  = 1,
        byrow = TRUE,    # ensures spacing applies cleanly
        override.aes = list(
          size = 4.5  # artificially large point/line increases vertical spacing
        )

      )
    ) +
    scale_color_manual(
      values = cols,
      labels = wrapped_labels
    ) +
    theme(
      axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1),
      axis.title.x = element_text(size = 8),   # x-axis label size
      axis.title.y = element_text(size = 8),   # y-axis label siz
      legend.spacing.y = unit(4, "mm"),   # increase vertical gap
      legend.key.size   = unit(0.3, "cm"),
      legend.key.height = unit(0.3, "cm"),
      legend.key.width  = unit(0.3, "cm"),
      legend.title = element_text(size = 8),
      legend.text  = element_text(size = 7),
      legend.box.margin = margin(0, 2, 0, 2)  # compress legend box
    )

  plot
}

oac_plot(mean_ee,"Mean energy efficiency score",dom_summary, xlims = c(2010,2024))
ggsave("plots/averge_ee_rating_v2.png", dpi = 300, width = 4, height = 6)

lsoa_plot = function(var = "dom_elec_kgco2e_percap",
                     title = "Change in Electrcity Emissions",
                     dat = lsoa_emissions_all,
                     bounds = bounds,
                     borders = borders,
                     islandBox = islandBox){

  yr1 = min(dat$year)
  yr2 = max(dat$year)

  tmap_options(component.autoscale = FALSE)

  dat = dat |>
    select(all_of(c("LSOA21CD","year",var))) |>
    filter(year %in% c(yr1, yr2)) |>
    pivot_wider(id_cols = "LSOA21CD", names_from = "year", values_from = all_of(var))
  dat$change = (dat[[as.character(yr2)]] - dat[[as.character(yr1)]]) / dat[[as.character(yr1)]] * 100
  dat$change[is.infinite(dat$change)] = NA

  message(names(dat))

  dat2 = left_join(bounds, dat, by = "LSOA21CD")

  m0 = tm_shape(dat2) +
    tm_fill(
      fill = "change",
      fill.scale = tm_scale_intervals(
        style = "fixed",
        breaks = c(
          min(dat$change, na.rm = TRUE),
          quantile(dat$change,
                   probs = c(0.01,0.2,0.4,0.6,0.8,0.99),
                   na.rm = TRUE),
          max(dat$change, na.rm = TRUE)
        ),
        values = "brewer.rd_yl_bu",
        label.style = "continuous",
        midpoint = 0
      ),
      fill.legend = tm_legend(
        title = paste0(title," ",yr1,"-",yr2),
        orientation = "landscape",
        position = tm_pos_out("center","bottom"),
        text.size = 1.2,
        title.size = 1.5,
        bg.color = "white",
        bg.alpha = 0.8,
        frame = FALSE,
        width = 32
      )
    ) +
    tm_shape(islandBox) +
    tm_borders(lwd = 1, col = "black") +
    tm_layout(
      frame = FALSE,
      inner.margins = c(0, 0, 0, 0),
      outer.margins = c(0, 0, 0, 0),
      scale = 0.5
    )

  m0



}


dom_lsoa_summary = dom_all |>
  st_drop_geometry() |>
  group_by(LSOA21CD, year) |>
  summarise(median_ee = median(CURRENT_ENERGY_EFFICIENCY, na.rm = TRUE),
            mean_ee = mean(CURRENT_ENERGY_EFFICIENCY, na.rm = TRUE))

dom_lsoa_summary = dom_lsoa_summary[!is.na(dom_lsoa_summary$year),]
dom_lsoa_summary = dom_lsoa_summary[dom_lsoa_summary$year <= 2024 & dom_lsoa_summary$year >= 2010,]
#dom_lsoa_summary2 = dom_lsoa_summary[dom_lsoa_summary$year <= 2022 & dom_lsoa_summary$year >= 2018,] # If you want scotland

m2 = lsoa_plot("mean_ee","% change in mean EPC score",dom_lsoa_summary,
               bounds,borders,islandBox)
tmap_save(m2,
          "plots/eceee_fig_epc_map_v2.png", dpi = 600, width = 4, height = 6)
