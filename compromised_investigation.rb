#! /usr/bin/env ruby
###########################################################################
#
# [+] Description: This script checks the http://haveibeenpwned.com database 
# for accounts compromised in PUBLICLY RELEASED breaches. Further API 
# documentation can be found at: https://haveibeenpwned.com/API/v2. Based on 
# the PwnedCheck gem and sample script written by Carl Sampson at
# http://github.com/sampsonc/PwnedCheck
# [+] Use Case: check list of user names, email addresses, and phone numbers 
# against database of accounts found in public breaches
#
#                          ~ author: nxkennedy ~
###########################################################################

#******** Usage ********#
# ruby compromised.rb <email-list.csv>
#
# Output: pwned-emails(#{today}).csv will contain the following columns:
# ["Account", "Finding", "BreachName", "BreachDate", "MostRecent"]
#**********************#



require 'csv'
require 'date'
require 'paint'
require 'progress_bar'
require 'pwnedcheck'



####### Clear the terminal screen ruby-style and print our banner #########
print "\e[2J\e[f"
banner = <<EOB

......................-/oydmmmdddyso+/::/odhs+/-..........................
.....................-:oy/+dmds:`          :mdhs+:-........................
.....................-/sh` `.               .hmmhy+:........................
.....................-/sy                 `` .ymmmhyo/:-......................
.....................-/ss                    `/hmmmdhys+:-....................
.....................:+ss                   `..`//:-::syo:-...................
................-::/++shy                       smmmdddyo:....................
.............-:/+syhhhhhs                  ``-/odmmmhhyo/-....................
............-/oyhddhyso:`            `.:/ooosshdhyyyys+:-.....................
.............:/oyyyso/-`            `-:/+ooos+:.`yhs+:-.......................
..............--/+osysso+.         ```      +y.`/hs/-.........................
.................--::/+syh-                `ym-+ddy+:.........................
................--::::/oyh:                .yy` -yho/-........................
................:+osssyy+`                  :`    +ho/-.......................
................-/oyhdo.                           /hs/:-.....................
..............--:+shs.                              +hys+//:---...............
.........-://++osys-                                 +mmdhhyso+/:--...........
.......:/oyyhdddd/                                    `-/oydmmdhys+/:-........
....-:/oyyso/::-`                                      oyso+oooshmdhso/:-.....
..-:/oys- ``-+s-``                        `            `syysohhhso+shdyo/-....
.-:oyh/   ``--:-:-                                      -+os-.+s++ooosdho/-...
.-/sho       ``                                   `  ``  --::  -:``` `ody+:...
.:+yy`                                               `-.    ..    ``   sho:-..
-/oh-                                                        `         .ys/-..
-+ss                   COMPROMISED PT. I:                               os/-..
-+y/                     INVESTIGATION                                  os/-..
EOB

puts Paint[banner, :red, :bold]

####### Specify input file and output file #########
#@target = ARGV[1]
@src = ARGV[0]

####### Calculate time to completion #########
requestDelay = 1.5
fileLength = 0
CSV.readlines(@src).each do |line|
    fileLength += 1
end

####### Reading from CSV input, writing to CSV output #########
notFound = 0
invalid = 0
progress = ProgressBar.new(fileLength)
today = Date.today.to_s
CSV.open("pwned-emails(#{today}).csv", "w+") do |csv|
    csv << [
        "Account",
        "Finding",
        "BreachName",
        "BreachDate",
        "MostRecent",
    ]
    puts Paint["\n RUNNING A BACKGROUND CHECK ON #{fileLength.to_s} SUSPICIOUS ALIASES...\n", :cyan]
    CSV.readlines(@src).each do |account|
        # Account is an array. Makes it a string
        account = account.first
        most_recent = nil
        data = [account]

        begin
            sites = PwnedCheck::check(account)

            if sites.length == 0
                data << "Not Found"
                csv << data
                notFound += 1
            else
                sites.each do |site|

                    # API returns most recent breach first. We place an "x" next to that date
                    if most_recent
                        csv << [account, "COMPROMISED", site["Title"], site["BreachDate"], nil]
                    else
                        most_recent = Date.parse(site["BreachDate"])
                        csv << [account, "COMPROMISED", site["Title"], site["BreachDate"], "x"]
                    end

                end
            end

        rescue PwnedCheck::InvalidEmail => e
            data << e.message
            csv << data
            invalid += 1

        # If the query is throttled by the HIBP api, sites == nil, which doesn't have a length method. This pauses to reset the connection and then retries the throttled query.
        rescue NoMethodError
            puts Paint["\n** REQUEST THROTTLED BY API. INCREASE SLEEP TIME BETWEEN REQUESTS. **", :red]
            puts Paint["[-] PAUSING 20 SECONDS TO RESET CONNECTION. . .", :red]
            sleep 20
            puts Paint["[-] RESUMING LOOKUP\n", :yellow]
            retry
        end

        #puts data.inspect  # here to troubleshoot output

        ####### Throttling. The website says 150 milliseconds but is pretty touchy. Adjust it to whatever works for you. Keep in mind that if using this from a public source (workplace), your IP may be throttled if other users try to make requests #########
        sleep requestDelay
        progress.increment!
    end
end

####### Final Output #########
compromised = (fileLength - (notFound + invalid)).to_s
puts Paint["\n\n ALIAS INVESTIGATION COMPLETE", :cyan]
puts "___"
puts Paint["[☠] ASSOCIATED WITH ILLICIT ACTIVITY: #{compromised}", :red]
puts Paint["[✓] CLEARED OF SUSPICION: #{notFound.to_s}", :green]
puts Paint["[⚡] BAD LEADS: #{invalid.to_s}\n\n", :yellow]
