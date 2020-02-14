# Filename: "A-League_tables.R"

# Reads in data from wikipedia of history of all A-league tables
# Note that the format of the input data may change as people change wikipedia entries.

# Team colours in HTML format from https://imagecolorpicker.com/en.

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Libraries & directories

# Read in data files
path = "C:/Users/Hollie/Documents/Pete/R-files"
input_path = paste(path, "/input", sep="")
output_path = paste(path, "/R_output", sep="")

setwd(path)
# create a directory for the output data if it does not already exist
ifelse(!dir.exists("R_output"), dir.create("R_output"), "Directory already exists")

# move up one directory and down one to R_output
#setwd("../R_output/")


# Specify packages (libraries) that are commonly used
library(lubridate)
library(tidyverse)
library(scales)

# Reading tables from a wikipedia page
library(rvest)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Parameters 

# From 2005-06 to 2018-19
end_yr = seq(2006, 2019, by = 1)
start_yr = end_yr - 1
seasons = paste(start_yr, "-", substr(end_yr,3,4), sep = "")

# manually identify which table on wikipedia page shows the league table
# Note: will need to amend values if on wikipedia a new table is inserted above the league table
wiki_table_no = c(6, rep(4,3), 5, 5, rep(6,8))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Functions 
make_graph = function(team_abbrev) {
  data_for_graph = a_league_tables %>% 
    filter(abbrev == team_abbrev)
  
  max_teams_in_season = max(season_totals$count)
  start_yr = min(data_for_graph$season)
  end_yr = max(data_for_graph$season)
  min_yr = min(data_for_graph$yr_end)
  max_yr = max(data_for_graph$yr_end)
  
  #Breaks for background rectangles, other formatting
  rects = data.frame(xstart = c(-Inf,2009.5,2011.5), xend = c(2009.5, 2010.5, Inf),
                     ystart = c(11, 11, 11), yend = c(8, 10, 10))
  x_intercepts = data_for_graph$yr_end[(data_for_graph$yr_end %% 5) == 0]
  
  # Graph of league position
  graph_1 = ggplot(data_for_graph, aes(x = yr_end, y = Pos)) +
    geom_line(size=1.15, colour = data_for_graph$team_colours[1]) +
    geom_point(aes(colour=as.factor(champion), size = as.factor(champion))) +
    scale_colour_manual(values = c(data_for_graph$second_colour[1], "red")) +  # colours for geom_points
    scale_size_manual(values = c(2,4)) +
    
    # axes
    geom_rect(data = rects, aes(xmin = xstart, xmax = xend, ymin = Inf, ymax = yend+0.1),  # 0.1 for margin
              fill = "white", alpha = 1.0, inherit.aes = FALSE) +
    scale_y_continuous(trans = "reverse", expand = c(0,0.1), breaks= pretty_breaks()) +
    scale_x_continuous(breaks= pretty_breaks()) +
    coord_cartesian(xlim = c(min_yr, max_yr), ylim = c(max_teams_in_season, 1)) +
    geom_vline(xintercept=x_intercepts,  linetype="dotted") +
    theme(panel.border = element_rect(fill=NA)) +
    
    # titles
    ggtitle(paste("A-League position of", data_for_graph$current_name[1], "from", start_yr, "to", end_yr)) + 
    theme(plot.title = element_text(lineheight=1.0, face="bold", hjust = 0.5)) +
    labs(x="Year", y="Position") +
    theme(plot.margin=unit(c(0.5,1,1.5,1.2),"cm")) +
    theme(legend.position = "none") +
    
    # horizontal lines for number of finals teams
    {if(min_yr<2010)geom_segment(aes(x = min(yr_end), xend = min(max_yr,2009.5), y = 4.5, yend = 4.5), linetype="dotted", colour = "black", size = 1)} +
    {if((min_yr<2010)&(max_yr>2010))geom_segment(aes(x = 2009.5, xend = 2009.5, y = 4.5, yend = 6.5), linetype="dotted", colour = "black", size = 1)} +
    {if(max_yr>2010)geom_segment(aes(x = max(2009.5,min_yr), xend = max(yr_end), y = 6.5, yend = 6.5), linetype="dotted", colour = "black", size = 1)}
  
  graph_1
}


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Read in input files
setwd(input_path)

a_league_teams = read_csv("a_league_teams.csv")

# read all league tables in one loop
# to read a league table manually, see A-League_workings.R
tables = list()
for (j in 1:length(seasons)) {
  table = read_html(paste("https://en.wikipedia.org/wiki/", seasons[j], "_A-League", sep = ""))
  tables_wiki <- table %>%
    html_nodes(".wikitable") %>%
    html_table(fill = TRUE)
  
  tables[[j]] <- tables_wiki[[wiki_table_no[j]]] %>% # added to my list
    mutate(season_no = j, season = seasons[j])
}

# Review headers in each of the tables - need consistency of names for combining tables
headers_all = c()
for (j in 1:length(seasons)) {
  header = colnames(tables[[j]])
  headers_all = rbind(header, headers_all)
}

header = colnames(tables[[1]]) %>%
  str_replace("\\[.*\\]", "")                      # remove text inside square brackets

for (j in 1:length(seasons)) {
  colnames(tables[[j]]) = header
}

# convert from list to data frame
tables_all = do.call(rbind, lapply(tables, as.data.frame))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Select relevant data, and then data manipulations
a_league_tables = tables_all %>% 
  mutate(Team = str_replace(Team, "\\[.*\\]", ""),            # remove text inside square brackets
         champion = ifelse(substr(Team, nchar(Team) - 2, nchar(Team)) == "(C)", 1, 0),
         premiers = ifelse(Pos == 1, 1, 0),
         finals = ifelse(str_detect(tolower(Qualification), pattern = "finals"), 1, 0),
         Team = str_replace(Team, " \\(C\\)", ""),            # to get consistency in team name
         Pts = str_replace(Pts, "\\[.*\\]", ""),
         pts_deducted = as.numeric(Pts) - (3 * W + D),
         goal_diff = GF - GA,
         yr_end = as.numeric(substr(season, 1, 4)) + 1)

a_league_tables$Pts = as.numeric(a_league_tables$Pts)


# Create a table of team names, including history & past team name changes
teams = as.tibble(unique(a_league_tables$Team))
colnames(teams) = c("previous_name")
teams = teams %>% 
  mutate(current_name = previous_name)
teams$current_name = ifelse(teams$previous_name == "Melbourne Heart", "Melbourne City", teams$current_name)
teams$current_name = ifelse(teams$previous_name == "Queensland Roar", "Brisbane Roar", teams$current_name)

teams_all = left_join(teams, a_league_teams, by = c("current_name" = "current_name"))

a_league_tables_all = left_join(a_league_tables, teams_all, by = c("Team" = "previous_name"))
a_league_tables = a_league_tables_all
rm("a_league_tables_all")


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Analysis of A-League tables data
# Make all-time league table
all_time = group_by(a_league_tables, current_name) %>%
  summarise(count = n(),
            Total_Pld = sum(Pld),
            Total_W = sum(W),
            Total_D = sum(D),
            Total_L = sum(L),
            Total_GF = sum(GF),
            Total_GA = sum(GA),
            Total_GD = sum(goal_diff),
            Total_Pts = sum(Pts),
            count_champions = sum(champion),
            count_premiers = sum(premiers),
            count_finals = sum(finals),
            best = min(Pos),
            first_season = min(season),
            last_season = max(season)) %>%
  arrange(desc(Total_Pts), desc(Total_GD), desc(Total_GF))


# champions by final position
champions = filter(a_league_tables, champion == 1)
champions_by_Pos = group_by(champions, Pos) %>%
  summarise(count = n())

# totals by season
season_totals = group_by(a_league_tables, season, yr_end) %>%
  summarise(count = n(),
            Total_Pld = sum(Pld),
            Total_W = sum(W),
            Total_D = sum(D),
            Total_L = sum(L),
            Total_GF = sum(GF),
            Total_GA = sum(GA),
            Total_GD = sum(goal_diff),
            Total_Pts = sum(Pts))

# no. of teams in finals
finals_teams = a_league_tables %>% 
  filter(str_detect(tolower(Qualification), pattern = "finals")) %>% 
  group_by(season, yr_end) %>% 
  summarise(finals_teams = max(Pos))

# list of all team abbreviations
teams_unique = unique(a_league_tables$abbrev)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# checks on data for consistency
error_check_pts = a_league_tables %>% 
  filter(!Pts == (3 * W + D))

error_check_pld = a_league_tables %>%
  filter(!Pld == (W + D + L))

error_check_results = season_totals %>%
  filter(!Total_W == Total_L)

error_check_gd = season_totals %>%
  filter(!Total_GD == 0)

error_check_pos = group_by(a_league_tables, season) %>%
  summarise(count = n(),
            sum_pos = sum(Pos)) %>%
  mutate(exp_sum_pos = count * (count + 1) / 2,
         pos_diff = sum_pos - exp_sum_pos) %>%   # error if calculated difference (pos_diff) is not zero
  filter(!(pos_diff == 0))


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# run function to produce graph for a specific team
make_graph("ADE") 
make_graph("SFC")
make_graph("CCM") 
make_graph("NEW")
make_graph("PER")
make_graph("BRI")
make_graph("MVI") 
make_graph("NZK")
make_graph("WEL")
make_graph("GCU")
make_graph("NQF")
make_graph("MCI")
make_graph("WSW")


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# export file to csv format
names(all_time) <- gsub(x = names(all_time), pattern = "_", replacement = " ") 

setwd(output_path)
write.csv(a_league_tables, file = "A_league_tables_all.csv")
write.csv(all_time, file = "A_league_all_time.csv")
setwd(path) 

# export single graph
setwd(output_path)
ggsave("graph_ggsave.pdf")
setwd(path)

# export multiple graphs
for (i in 1:length(teams_unique)) {
  make_graph(teams_unique[i])
  setwd(output_path)
  ggsave(paste("graph_ggsave_", teams_unique[i], ".pdf", sep=""))
}
setwd(path)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# End