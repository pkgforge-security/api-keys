#!/usr/bin/bash

#A bit of Styling
RED='\033[31m'
GREEN='\033[32m'
DGREEN='\033[38;5;28m'
GREY='\033[37m'
BLUE='\033[34m'
YELLOW='\033[33m'
PURPLE='\033[35m'
PINK='\033[38;5;206m'
VIOLET='\033[0;35m'
RESET='\033[0m'
NC='\033[0m'

#Banner
echo -e "${PURPLE}"
cat << "EOF"       
 _  |  o 
(_| |< |  : Api Key | Tokens validator 
EOF
echo -e "${NC}"

# Straight from GIT
#bash <( curl -qfsSL "https://raw.githubusercontent.com/pkgforge-security/api-keys/main/scripts/aki_amass_datasources_yaml_checker.sh") -a "/path/to/amass/datasources.yaml" --quota

#Help / Usage
if [[ "$*" == *"-h"* ]] || [[ "$*" == *"--help"* ]] || [[ "$*" == *"help"* ]] ; then
  echo -e "${YELLOW}➼ Usage${NC}: ${PURPLE}aki-amass${NC} ${BLUE}-a${NC} ${GREEN}<your/amass/datasources.yaml>${NC}\n"
  echo -e "➼ ${BLUE}Extended Help${NC} :\n"
    if [ ! -f "$HOME/.config/amass/datasources.yaml" ]; then
        echo -e "Your ${YELLOW}$HOME/.config/amass/datasources.yaml${NC} ${RED}does not exist${NC}\nYou ${GREEN}must create${NC} one: ${BLUE}https://github.com/owasp-amass/amass/blob/master/examples/datasources.yaml${NC}\nElse use:"
        echo -e "        ${BLUE}-a${NC},  ${BLUE}--amass${NC}     ${GREEN}<your/amass/datasources.yaml>${NC} (${YELLOW}Required${NC})\n"
    else
        echo -e "➼ By ${BLUE}default ${YELLOW}$HOME/.config/amass/datasources.yaml${NC} will be used\n  To ${BLUE}change${NC} it use:"
        echo -e "                   ${BLUE}-a${NC},  ${BLUE}--amass${NC}     ${GREEN}<your/amass/datasources.yaml>${NC}\n"
    fi   
    echo -e "${BLUE}Optional flags${NC} :"
         echo -e " ${BLUE}-q${NC},   ${BLUE}--quota${NC}      ${YELLOW}Show ${PURPLE}Usage Quota${NC} (${BLUE}limited${NC})"                    
 exit 0      
fi   

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -a|--amass)
        amass_config="$2"
        shift 
        shift 
        ;;
        -q|--quota)
        quota=1
        shift
        ;;        
        *)    
        echo -e "${RED}Error: Invalid option ${YELLOW}'$key'${NC} , try ${BLUE}--help${NC} for Usage"
        exit 1
        ;;
    esac
done

#Dependency checks
echo -e "${GREEN}ⓘ Checking | Downloading ${BLUE}Dependencies${NC}\n"
# Only require curl + pip, prefer binaries for jq | yq
mkdir -p "/tmp/aki/bin"
export PATH="/tmp/aki/bin:$PATH"
# Check pip
if ! command -v pip >/dev/null 2>&1; then
   echo -e "${RED}\u2717 Fatal${NC}: ${PINK} python | pip wasn't found !${NC}"
   if ! command -v pip3 >/dev/null 2>&1; then
      echo -e "${RED}\u2717 Fatal${NC}: ${PINK} python3 | pip3 wasn't found either !${NC}"
      echo -e "${YELLOW}Install them Manually${NC}"
   fi
fi   
#jq, for parsing json
if ! command -v jq >/dev/null 2>&1; then
    echo -e "➼ ${PINK}jq${NC} is ${RED}not installed${NC}. ${GREEN}Installing...${NC}"
    curl -qfsSL "https://bin.pkgforge.dev/$(uname -m)-$(uname -s)/jq" -o "/tmp/aki/bin/jq"
    chmod +xwr "/tmp/aki/bin/jq"
fi
#yq, for parsing yaml
if ! command -v yq >/dev/null 2>&1; then
    echo -e "➼ ${PINK}yq${NC} is ${RED}not installed${NC}. ${GREEN}Installing...${NC}"
    curl -qfsSL "https://bin.pkgforge.dev/$(uname -m)-$(uname -s)/yq" -o "/tmp/aki/bin/yq"
    chmod +xwr "/tmp/aki/bin/yq"
fi
#Quota (ApiKeyBeast)
  curl -qfsSL "https://raw.githubusercontent.com/pkgforge-security/api-keys/main/scripts/apikeybeast.py" -o "/tmp/aki/bin/apikeybeast.py"
  pip install requests rich --upgrade --quiet
echo -e "${GREEN}ⓘ Configuring ${BLUE}Dependencies${NC}\n"

#Defaults
amass_config_def="$HOME/.config/amass/datasources.yaml"

#if no input passed to -a or --amass 
if [ -z "$amass_config" ]; then
        # Check if default amass config file exists
       if [[ -f $amass_config_def ]]; then
            echo -e "${GREEN}ⓘ Using default ${BLUE}amass config file${NC}: ${PURPLE}$amass_config_def${NC}\n"
            export amass_config=$amass_config_def
       else
           echo -e "${RED}\u2717 Couldn't find${NC} the default${NC} ${PURPLE}amass config file${NC}: ${RED}$amass_config_def${NC}"
           echo -e "${YELLOW}specify it manually using${NC} ${BLUE}-a${NC} | ${BLUE}--amass${NC}\n"
           #Nor was an input passed to -s or --subfinder
            if [[ -z $subfinder_config ]]; then
                   # Check if default subfinder config file exists
                    subfinder_config_def="$HOME/.config/subfinder/provider-config.yaml"            
                if [[ -f $subfinder_config_def ]]; then
                   echo -e "${GREEN}ⓘ Using default ${BLUE}subfinder config file${NC}: ${PURPLE}$subfinder_config_def${NC}\n"
                   export subfinder_config=$subfinder_config_def
                 else
                    echo -e "${RED}\u2717 Couldn't find${NC} the default${NC} ${PURPLE}subfinder config file${NC}: ${RED}$subfinder_config_def${NC}"
                    echo -e "${YELLOW}specify it manually using${NC} ${BLUE}-s${NC} | ${BLUE}--subfinder${NC}\n"
                    echo -e "${RED}\u2717 Fatal${NC}: Neither one of${PURPLE} amass${NC} | ${PURPLE}subfinder${NC}  ${BLUE}options was used${NC} nor a ${PURPLE}default config file${NC} [${GREEN}amass${NC}: ${PURPLE}$amass_config_def${NC} ${RED}Not Found${NC}] [${GREEN}subfinder${NC}: ${PURPLE}$subfinder_config_def${NC} ${RED}Not Found${NC}]\n"
                exit 1
                fi
            fi
        fi  
else
    echo -e "${GREEN}ⓘ Using Specified ${BLUE}amass config file${NC}: ${PURPLE}$amass_config${NC}\n"  
         if [ ! -f  $amass_config ]; then 
            echo -e "${RED}\u2717 Fatal${NC}: [ ${BLUE}amass config file${NC}: ${PURPLE}$amass_config${NC} ${RED}Not Found${NC} ]"
              if  [ -f  $amass_config_def ]; then  
                 echo -e "${GREEN}ⓘ Using default ${BLUE}amass config file${NC}: ${PURPLE}$amass_config_def${NC}\n"            
                 export amass_config=$amass_config_def
              else
                 echo -e "${RED}\u2717 Fatal${NC}: [ ${BLUE}Default${NC}: ${PURPLE}$amass_config_def${NC} ${RED}also Not Found${NC} ]\n"              
              fi        
         fi       
fi

#Re Check
#amass
if [ -n "$amass_config" ] && [ -e "$amass_config" ]; then
  echo -e "${YELLOW}Check ${GREEN}amass${NC} ${YELLOW}?${NC} : ${BLUE}Yes $(echo -e "${GREEN}\u2713${NC}")${NC}"
else
  echo -e "${YELLOW}Check ${GREEN}amass${NC} ${YELLOW}?${NC} : ${RED}No $(echo -e "${RED}\u2717${NC}")${NC}"
fi
#whether to show usage quotas     
if [ -z "$quota" ]; then
   echo -e "${YELLOW}Show ${BLUE}Quota Usage${YELLOW} ?${NC} : ${RED}No $(echo -e "${RED}\u2717${NC}")${NC}"
else
   echo -e "${YELLOW}Show ${BLUE}Quota Usage${YELLOW} ?${NC} : ${BLUE}Yes $(echo -e "${GREEN}\u2713${NC}")${NC}"     
fi 
echo -e "\n"
echo -e "${YELLOW}ⓘ Some API Checks will take${RED} longer${NC} to avoid ${GREEN}rate limits${NC} (Shodan, etc)\n ${BLUE}Please have ${GREEN}Patience${NC}\n"



#amass parser
if [ -n "$amass_config" ]; then
    amass_config_parsed=$(mktemp) && export amass_config_parsed="$amass_config_parsed"
    #Parse using yq (strip comments)
    cat "$amass_config" | yq '... comments=""' > "$amass_config_parsed"
    echo -e "${RED}"
    cat << "EOF"       
            .+++:.            :                             .+++.
      +W@@@@@@8        &+W@#               o8W8:      +W@@@@@@#.   oW@@@W#+
     &@#+   .o@##.    .@@@o@W.o@@o       :@@#&W8o    .@#:  .:oW+  .@#+++&#&
    +@&        &@&     #@8 +@W@&8@+     :@W.   +@8   +@:          .@8
    8@          @@     8@o  8@8  WW    .@W      W@+  .@W.          o@#:
    WW          &@o    &@:  o@+  o@+   #@.      8@o   +W@#+.        +W@8:
    #@          :@W    &@+  &@+   @8  :@o       o@o     oW@@W+        oW@8
    o@+          @@&   &@+  &@+   #@  &@.      .W@W       .+#@&         o@W.
     WW         +@W@8. &@+  :&    o@+ #@      :@W&@&         &@:  ..     :@o
     :@W:      o@# +Wo &@+        :W: +@W&o++o@W. &@&  8@#o+&@W.  #@:    o@+
      :W@@WWWW@@8       +              :&W@@@@&    &W  .o#@@W&.   :W@WWW@@&
        +o&&&&+.                                                    +oooo.
EOF
echo -e "${NC}"
    #Main Functions
   #ASNLookup  
    ASNLookup_api_keys=$(yq eval '.datasources[] | select(.name == "ASNLookup") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$ASNLookup_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="ASNLookup_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$ASNLookup_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="ASNLookup_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://asn-lookup.p.rapidapi.com/api?asn=AS13414" -H "Host: asn-lookup.p.rapidapi.com" -H "X-Rapidapi-Host: asn-lookup.p.rapidapi.com" -H "X-Rapidapi-Key: $api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} ASNLookup${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} ASNLookup${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
    #AlienVault
    alienvault_api_keys=$(yq eval '.datasources[] | select(.name == "AlienVault") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$alienvault_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="alienvault_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$alienvault_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="alienvault_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                         response=$(curl -qski "https://otx.alienvault.com/api/v1/user/me" │  -H "X-OTX-API-KEY: $api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} AlienVault${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC} or ${RED}Quota Exceeded${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} AlienVault${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
    #BeVigil
    BeVigil_api_keys=$(yq eval '.datasources[] | select(.name == "BeVigil") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$BeVigil_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="BeVigil_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$BeVigil_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="BeVigil_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://osint.bevigil.com/api/example.com/subdomains/" -H "X-Access-Token: $api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} BeVigil${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [ "$status_code" = "402" ]; then
                          echo -e "ⓘ ${VIOLET} BeVigil${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Quota Exceeded${NC}"
                        invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} BeVigil${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
    #BigDataCloud  
    BigDataCloud_api_keys=$(yq eval '.datasources[] | select(.name == "BigDataCloud") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$BigDataCloud_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="BigDataCloud_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$BigDataCloud_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="BigDataCloud_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://api-bdc.net/data/asn-info?asn=AS17501&localityLanguage=en&key=$api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} BigDataCloud${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC} or ${RED}Quota Exceeded${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} BigDataCloud${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #BinaryEdge  
    BinaryEdge_api_keys=$(yq eval '.datasources[] | select(.name == "BinaryEdge") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$BinaryEdge_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="BinaryEdge_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  #export BINARY_EDGE_API_KEY="$api_key"
                  i=$((i+1))
                  done <<< "$BinaryEdge_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="BinaryEdge_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://api.binaryedge.io/v2/user/subscription" -H "X-Key: $api_key" -H "Accept":"application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ]; then
                       echo -e "ⓘ ${VIOLET} BinaryEdge${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [ "$status_code" = "403" ]; then
                         echo -e "ⓘ ${VIOLET} BinaryEdge${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Quota Exceeded${NC}"
                       invalid_key_found=true
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                           echo -e "ⓘ ${VIOLET} BinaryEdge${NC}"
                           export BINARY_EDGE_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"
                           python3 "/tmp/aki/bin/apikeybeast.py" -s binaryedge     
                           echo -e "\n"                 
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} BinaryEdge${NC} : ${GREEN}\u2713${NC}" 
              fi  
         fi
   ##Used to be free, but became paid via rapidapi: https://rapidapi.com/projectxio/api/bufferover-run-tls/pricing
   ##Valid Old API Keys == 500 Server Error
   ##BufferOver  
    #BufferOver_api_keys=$(yq eval '.datasources[] | select(.name == "BufferOver") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    #invalid_key_found=false
    #      if [ -n "$BufferOver_api_keys" ]; then
    #              i=1
    #              while read -r api_key; do
    #              var_name="BufferOver_api_key_$i"
    #              eval "$var_name=\"$api_key\""
    #              i=$((i+1))
    #              done <<< "$BufferOver_api_keys"
    #                 #curl
    #                for ((j=1; ; j++)); do
    #                      var_name="BufferOver_api_key_$j"
    #                      api_key=${!var_name}
    #                 if [ -z "$api_key" ]; then
    #                   break
    #                 fi
    #                      response=$(curl -qski "https://tls.bufferover.run/dns?q=.example.com" -H "x-api-key: $api_key")
    #                      status_code=$(echo "$response" | awk '/HTTP/{print $2}')
    #                 if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
    #                   echo -e "ⓘ ${VIOLET} BufferOver${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC} or ${RED}Quota Exceeded${NC}"
    #                   invalid_key_found=true
    #                 elif [ "$status_code" = "500" ]; then
    #                    echo -e "ⓘ ${VIOLET} BufferOver${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 500 Server Error${NC}"
    #                   invalid_key_found=true
    #                 fi
    #          done
    #          if ! $invalid_key_found; then
    #              echo -e "ⓘ ${VIOLET} BufferOver${NC} : ${GREEN}\u2713${NC}"  
    #          fi  
    #     fi
   #BuiltWith  
    BuiltWith_api_keys=$(yq eval '.datasources[] | select(.name == "BuiltWith") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$BuiltWith_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="BuiltWith_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$BuiltWith_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="BuiltWith_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://api.builtwith.com/usagev2/api.json&KEY=$api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if echo "$response" | grep -q "Your key is invalid"; then
                       echo -e "ⓘ ${VIOLET} BuiltWith${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif echo "$response" | grep -q "You have used up your API allocation"; then
                       echo -e "ⓘ ${VIOLET} BuiltWith${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Quota Exceeded${NC}"
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                           echo -e "ⓘ ${VIOLET} BuiltWith${NC}"
                           export BUILT_WITH_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s builtwith      
                           echo -e "\n"                 
                     fi                                             
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} BuiltWith${NC} : ${GREEN}\u2713${NC}"            
              fi  
         fi
   #Censys  
    Censys_api_keys=$(yq eval '.datasources[] | select(.name == "Censys") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
        invalid_key_found=false
          if [ -n "$Censys_api_keys" ]; then
                    i=1
                    while read -r apikey && read -r secret; do
                    encoded=$(echo -n "$apikey:$secret" | base64 | tr -d '[:space:]')
                    varname="Censys_cred_$i"
                    eval "$varname=\"$encoded\""
                    #echo "$varname=${!varname}"
                    i=$((i+1))
                  done <<< "$Censys_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="Censys_cred_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://search.censys.io/api/v1/account" -H "accept: application/json" -H "Authorization: Basic $api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} Censys${NC} ${YELLOW}API key : Secret${NC} = ${BLUE}$(echo -n "$api_key" | base64 -d)${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                           echo -e "ⓘ ${VIOLET} Censys${NC}"
                           export CENSYS_USERNAME=$(curl -qsk "https://search.censys.io/api/v1/account" -H "Authorization: Basic $api_key" -H "accept: application/json" | jq -r '.login')
                           export CENSYS_AUTH="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s censys      
                           echo -e "\n"    
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} Censys${NC} : ${GREEN}\u2713${NC}"
              fi  
         fi
   #CertCentral  
    #CertCentral_api_keys=$(yq eval '.datasources[] | select(.name == "CertCentral") | .creds.account' $amass_config_parsed -o json | jq -r '"\(.username):\(.apikey)"' | grep -v 'null')
    CertCentral_api_keys=$(yq eval '.datasources[] | select(.name == "CertCentral") | .creds.account' $amass_config_parsed -o json | jq -r '"\(.apikey)"' | grep -v 'null')
    invalid_key_found=false
          if [ -n "$CertCentral_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="CertCentral_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$CertCentral_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="CertCentral_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://www.digicert.com/services/v2/user" -H "Content-Type: application/json" -H "X-DC-DEVKEY: $api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} CertCentral${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} CertCentral${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi        
   #Chaos  
    Chaos_api_keys=$(yq eval '.datasources[] | select(.name == "Chaos") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$Chaos_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="Chaos_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$Chaos_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="Chaos_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://dns.projectdiscovery.io/dns/example.com/subdomains" -H "Authorization: $api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} Chaos${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} Chaos${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi   
   #Cloudflare  
    Cloudflare_api_keys=$(yq eval '.datasources[] | select(.name == "Cloudflare") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$Cloudflare_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="Cloudflare_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$Cloudflare_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="Cloudflare_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski  "https://api.cloudflare.com/client/v4/accounts" -H "Authorization: Bearer $api_key" -H "Content-Type: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "400" ] || [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} Cloudflare${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} Cloudflare${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
# yq eval '.datasources[] | select(.name == "DNSDB") | .creds.account.apikey' $amass_config_parsed | grep -v 'null'
# yq eval '.datasources[] | select(.name == "DNSlytics") | .creds.account.apikey' $amass_config_parsed | grep -v 'null'
# yq eval '.datasources[] | select(.name == "DNSRepo") | .creds.account.apikey' $amass_config_parsed | grep -v 'null'
# yq eval '.datasources[] | select(.name == "Deepinfo") | .creds.account.apikey' $amass_config_parsed | grep -v 'null'
# yq eval '.datasources[] | select(.name == "Detectify") | .creds.account.apikey' $amass_config_parsed | grep -v 'null'         
   #FacebookCT  
    FacebookCT_api_keys=$(yq eval '.datasources[] | select(.name == "FacebookCT") | .creds' $amass_config_parsed -o json | jq -r '.[] | "\(.apikey):\(.secret)"' | grep -v 'null' )
        invalid_key_found=false
     if [ -n "$FacebookCT_api_keys" ]; then
              i=1
              while read -r api_key; do
              varname="FacebookCT_cred_$i"
              eval "$varname=\"$api_key\""
              #echo "$varname=${!varname}"
               i=$((i+1))
             done <<< "$FacebookCT_api_keys"
            # curl
             for ((j=1; ; j++)); do
               var_name="FacebookCT_cred_$j"
               api_key=${!var_name}
               if [ -z "$api_key" ]; then
                break
                fi                
              response=$(curl -qski "https://graph.facebook.com/oauth/access_token?client_id=${api_key%:*}&client_secret=${api_key#*:}&redirect_uri=&grant_type=client_credentials")
              status_code=$(echo "$response" | awk '/HTTP/{print $2}')
              if [ "$status_code" = "400" ] || [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                  echo -e "ⓘ ${VIOLET} FacebookCT${NC} ${YELLOW}Username:Password${NC} = ${BLUE}${api_key}${NC} ${RED}\u2717 Invalid${NC}"
                  invalid_key_found=true
              fi
            done
         if ! $invalid_key_found; then
            echo -e "ⓘ ${VIOLET} FacebookCT${NC} : ${GREEN}\u2713${NC}"  
         fi  
      fi  
   #fofa  
    fofa_api_keys=$(yq eval '.datasources[] | select(.name == "FOFA") | .creds' $amass_config_parsed -o json | jq -r '.[] | "\(.username):\(.apikey)"' | grep -v 'null')
     invalid_key_found=false
     if [ -n "$fofa_api_keys" ]; then
              i=1
              while read -r api_key; do
              varname="fofa_cred_$i"
              eval "$varname=\"$api_key\""
               i=$((i+1))
             done <<< "$fofa_api_keys"
            # curl
             for ((j=1; ; j++)); do
               var_name="fofa_cred_$j"
               api_key=${!var_name}
               if [ -z "$api_key" ]; then
                break
                fi
              response=$(curl -qfsSL "https://fofa.info/api/v1/info/my?email=${api_key%:*}&key=${api_key#*:}" -H "Accept: application/json" | jq -r '.error')
              if echo "$response" | grep -q "true"; then
                  echo -e "ⓘ ${VIOLET} fofa${NC} ${YELLOW}fofa_api_email : fofa_api_key${NC} = ${BLUE}${NC}${api_key} ${RED}\u2717 Invalid${NC}"
                  invalid_key_found=true
              fi
            done
         if ! $invalid_key_found; then
            echo -e "ⓘ ${VIOLET} fofa${NC} : ${GREEN}\u2713${NC}"  
         fi  
      fi        
   #FullHunt  
    FullHunt_api_keys=$(yq eval '.datasources[] | select(.name == "FullHunt") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$FullHunt_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="FullHunt_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$FullHunt_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="FullHunt_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl --ipv4 -qski "https://fullhunt.io/api/v1/auth/status" -H "X-API-KEY: $api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} FullHunt${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} FullHunt${NC}"
                           export FullHunt_USERNAME=$(curl -qsk "https://fullhunt.io/api/v1/auth/status" -H "X-API-KEY: $api_key" -H "Accept: application/json" | jq -r '.user.first_name')
                           export FullHunt_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s fullhunt      
                           echo -e "\n"                           
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} FullHunt${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #GitHub  
    GitHub_api_keys=$(yq eval '.datasources[] | select(.name == "GitHub") | .creds' $amass_config_parsed -o json | jq -r '.[] | "\(.apikey)"' | grep -v 'null')
    invalid_key_found=false
          if [ -n "$GitHub_api_keys" ]; then
            echo -e "ⓘ ${VIOLET} Github${NC} has ${YELLOW}Rate Limits${NC} so have ${GREEN}Patience${NC}"
                  i=1
                  while read -r api_key; do
                  var_name="GitHub_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$GitHub_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="GitHub_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski  "https://api.github.com/user" -H "Authorization: Bearer $api_key" -H "Accept: application/vnd.github+json"  && sleep 20s)
                          if echo "$response" | grep -q "Bad credentials"; then   
                           echo -e "ⓘ ${VIOLET} GitHub${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                           invalid_key_found=true         
                          elif [ "$status_code" = "403" ]; then
                           echo -e "ⓘ ${VIOLET} GitHub${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}! 403 Forbidden${NC}"     
                           invalid_key_found=true                                                          
                          fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} GitHub${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi 
   #GitLab  
    GitLab_api_keys=$(yq eval '.datasources[] | select(.name == "GitLab") | .creds' $amass_config_parsed -o json | jq -r '.[] | "\(.apikey)"' | grep -v 'null')
    invalid_key_found=false
          if [ -n "$GitLab_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="GitLab_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$GitLab_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="GitLab_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://gitlab.com/api/v4/user" -H "PRIVATE-TOKEN: $api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] ; then
                       echo -e "ⓘ ${VIOLET} GitLab${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [ "$status_code" = "403" ] ; then
                       echo -e "ⓘ ${VIOLET} GitLab${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\U0001F480 BLOCKED${NC}"
                       invalid_key_found=true      
                     fi                   
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} GitLab${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi       
   #Hunter  
    Hunter_api_keys=$(yq eval '.datasources[] | select(.name == "Hunter") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$Hunter_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="Hunter_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$Hunter_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="Hunter_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://api.hunter.io/v2/account?api_key=$api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} Hunter${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} Hunter${NC}"
                           export HUNTER_USER=$(curl -qsk "https://api.hunter.io/v2/account?api_key=$api_key" -H "Accept: application/json" | jq -r '.data.first_name')
                           export HUNTER_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s hunterio      
                           echo -e "\n"                           
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} Hunter${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #IntelX          
    IntelX_api_keys=$(yq eval '.datasources[] | select(.name == "IntelX") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$IntelX_api_keys" ]; then
          echo -e "ⓘ ${VIOLET} IntelX${NC} has ${YELLOW}Rate Limits${NC} so have ${GREEN}Patience${NC}"
          echo -e "If ${RED}too may errors${NC}\n ${YELLOW}Try Manually${NC}: ${BLUE} https://github.com/Azathothas/Arsenal/tree/main/aki#verification${NC}"                  
                  i=1
                  while read -r api_key; do
                  var_name="IntelX_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$IntelX_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="IntelX_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://2.intelx.io/authenticate/info" -H "x-key:$api_key" -H "Accept: application/json" && sleep 30s)
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] ; then
                       echo -e "ⓘ ${VIOLET} IntelX${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [ "$status_code" = "403" ] ; then
                       echo -e "ⓘ ${VIOLET} IntelX${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Rate Limited${NC}"                      
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} IntelX${NC}"
                           export INTELX_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s intelx   
                           sleep 62s   
                           echo -e "\n"                           
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} IntelX${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #IPdata  
    IPdata_api_keys=$(yq eval '.datasources[] | select(.name == "IPdata") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$IPdata_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="IPdata_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$IPdata_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="IPdata_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://api.ipdata.co/?api-key=$api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} IPdata${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} IPdata${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #IPinfo  
    IPinfo_api_keys=$(yq eval '.datasources[] | select(.name == "IPinfo") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$IPinfo_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="IPinfo_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$IPinfo_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="IPinfo_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://ipinfo.io/me?token=$api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} IPinfo${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [ "$status_code" = "429" ]; then
                          echo -e "ⓘ ${VIOLET} IPinfo${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Quota Exceeded${NC}"
                       invalid_key_found=true
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} IPinfo${NC}"
                           export IPINFO_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s ipinfo   
                           echo -e "\n"                                                     
                     fi                     
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} IPinfo${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi  
   #LeakIX  
    LeakIX_api_keys=$(yq eval '.datasources[] | select(.name == "LeakIX") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$LeakIX_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="LeakIX_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$LeakIX_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="LeakIX_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski  "https://leakix.net/domain/example.com" -H "api-key: $api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} LeakIX${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} LeakIX${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #Netlas  
    Netlas_api_keys=$(yq eval '.datasources[] | select(.name == "Netlas") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$Netlas_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="Netlas_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$Netlas_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="Netlas_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski  "https://app.netlas.io/api/users/current/" -H "X-Api-Key: $api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [  "$status_code" = "400" ] || [  "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} Netlas${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} Netlas${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #NetworksDB  
    NetworksDB_api_keys=$(yq eval '.datasources[] | select(.name == "NetworksDB") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$NetworksDB_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="NetworksDB_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$NetworksDB_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="NetworksDB_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://networksdb.io/api/key" -H "X-Api-Key: $api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                      if echo "$response" | grep -q "API key inactive"; then  
                       echo -e "ⓘ ${VIOLET} NetworksDB${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}! Inactive${NC}" 
                       invalid_key_found=true
                      elif echo "$response" | grep -q "wrong API key"; then
                       echo -e "ⓘ ${VIOLET} NetworksDB${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} NetworksDB${NC}"
                           export NETWORKS_DB_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s networkdb   
                           echo -e "\n"                           
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} NetworksDB${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #PassiveTotal  
    PassiveTotal_api_keys=$(yq eval '.datasources[] | select(.name == "PassiveTotal") | .creds.account' $amass_config_parsed -o json | jq -r '"\(.username):\(.apikey)"' | grep -v 'null')
        invalid_key_found=false
          if [ -n "$PassiveTotal_api_keys" ]; then
                    i=1
                    while read -r apikey && read -r secret; do
                    encoded=$(echo -n "$apikey:$secret" | base64 | tr -d '[:space:]')
                    varname="PassiveTotal_cred_$i"
                    eval "$varname=\"$encoded\""
                    #echo "$varname=${!varname}"
                    i=$((i+1))
                  done <<< "$PassiveTotal_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="PassiveTotal_cred_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://api.riskiq.net/pt/v2/account/quota" -H "Authorization: Basic $api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} PassiveTotal${NC} ${YELLOW}API key : Secret${NC} = ${BLUE}$(echo -n "$api_key" | base64 -d)${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} PassiveTotal${NC}"
                           export PASSIVE_TOTAL_USERNAME=$(curl -qsk "https://api.riskiq.net/pt/v2/account/quota" -H "Authorization: Basic $api_key" -H "Accept: application/json" | jq -r '.user.owner')
                           export PASSIVE_TOTAL_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s passivetotal   
                           echo -e "\n"                           
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} PassiveTotal${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi   
   #Pastebin  
    Pastebin_api_keys=$(yq eval '.datasources[] | select(.name == "Pastebin") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$Pastebin_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="Pastebin_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$Pastebin_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="Pastebin_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://psbdmp.ws/api/v3/dump/KF7hDTp1?key=$api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "400" ] || [ "$status_code" = "401" ] || [ "$status_code" = "403" ] || [ "$status_code" = "500" ] ; then
                       echo -e "ⓘ ${VIOLET} Pastebin${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} Pastebin${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #PublicWWW  
    PublicWWW_api_keys=$(yq eval '.datasources[] | select(.name == "PublicWWW") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$PublicWWW_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="PublicWWW_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$PublicWWW_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="PublicWWW_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://publicwww.com/profile/api_status.xml?key=$api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if echo "$response" | grep -q "Wrong API key"; then
                        echo -e "ⓘ ${VIOLET} PublicWWW${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                        invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} PublicWWW${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #quake  
    quake_api_keys=$(yq eval '.datasources[] | select(.name == "Quake") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$quake_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="quake_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$quake_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="quake_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qfsSL "https://quake.360.net/api/v3/user/info" -H "X-QuakeToken: $api_key" -H "Accept: application/json" | jq .)
                          status_code=$(curl -qski "https://quake.360.net/api/v3/user/info" -H "X-QuakeToken: $api_key" -H "Accept: application/json" | awk '/HTTP/{print $2}')
                      if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then  
                       echo -e "ⓘ ${VIOLET} quake${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}! Invalid${NC}" 
                       invalid_key_found=true
                      elif echo "$response" | jq -r '.data.baned' | grep -q "true"; then
                       echo -e "ⓘ ${VIOLET} quake${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Banned${NC}"
                       invalid_key_found=true
                     elif [[ -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} quake${NC}"
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}" 
                           echo -e "${BLUE} Remaining Credits = ${YELLOW}$(echo $response | jq -r '.data.month_remaining_credit')${NC}"
                           echo -e "\n"                           
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} quake${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi          
   #Shodan  
    Shodan_api_keys=$(yq eval '.datasources[] | select(.name == "Shodan") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$Shodan_api_keys" ]; then
              #echo -e "ⓘ ${VIOLET} Shodan${NC} has ${YELLOW}Rate Limits${NC} so have ${GREEN}Patience${NC}"           
                  i=1
                  while read -r api_key; do
                  var_name="Shodan_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$Shodan_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="Shodan_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://api.shodan.io/api-info?key=$api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} Shodan${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [ "$status_code" = "429" ]; then
                       echo -e "ⓘ ${VIOLET} Shodan${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Failed Checks${NC} [${YELLOW}429: Too many requests${NC}]"
                       invalid_key_found=true   
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} Shodan${NC}"
                           export SHODAN_API_KEY="$api_key" 
                           export SHODAN_USERNAME=$(curl -qsk "https://api.shodan.io/account/profile?key=$api_key" -H "Accept: application/json" | jq -r '.display_name')
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s shodan      
                           echo -e "\n"                           
                     fi                   
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} Shodan${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi 
   #SecurityTrails  
    SecurityTrails_api_keys=$(yq eval '.datasources[] | select(.name == "SecurityTrails") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$SecurityTrails_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="SecurityTrails_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$SecurityTrails_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="SecurityTrails_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://api.securitytrails.com/v1/account/usage" -H "APIKEY:$api_key" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} SecurityTrails${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [ "$status_code" = "429" ]; then
                      echo -e "ⓘ ${VIOLET} SecurityTrails${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED} Quota Exceeded${NC}"
                     elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} SecurityTrails${NC}"                          
                           export SECURITY_TRAILS_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s securitytrails   
                           echo -e "\n"                           
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} SecurityTrails${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #Spamhaus  
     Spamhaus_api_keys=$(yq eval '.datasources[] | select(.name == "Spamhaus") | .creds.account' $amass_config_parsed -o json | jq -r '"\(.username):\(.password)"' | grep -v 'null')
     invalid_key_found=false
     if [ -n "$Spamhaus_api_keys" ]; then
              i=1
              while read -r api_key; do
              varname="Spamhaus_cred_$i"
              eval "$varname=\"$api_key\""
               i=$((i+1))
             done <<< "$Spamhaus_api_keys"
            # curl
             for ((j=1; ; j++)); do
               var_name="Spamhaus_cred_$j"
               api_key=${!var_name}
               if [ -z "$api_key" ]; then
                break
                fi
              response=$(curl -qski "https://api.spamhaus.org/api/v1/login" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"username\":\"${api_key%:*}\", \"password\":\"${api_key#*:}\", \"realm\":\"intel\"}")
              status_code=$(echo "$response" | awk '/HTTP/{print $2}')
              if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                  echo -e "ⓘ ${VIOLET} Spamhaus${NC} ${YELLOW}Username : Password${NC} = ${BLUE}${NC}${api_key} ${RED}\u2717 Invalid${NC}"
                  invalid_key_found=true
              fi
            done
         if ! $invalid_key_found; then
            echo -e "ⓘ ${VIOLET} Spamhaus${NC} : ${GREEN}\u2713${NC}"  
         fi  
      fi    
   #Twitter  
    Twitter_api_keys=$(awk '/^\[data_sources\.Twitter\.account[0-9]+\]$/{flag=1;next} /^\[/{flag=0} flag && /apikey/{print $3} flag && /secret/{print $3}' $amass_config_parsed)
        invalid_key_found=false
          if [ -n "$Twitter_api_keys" ]; then
                    i=1
                    while read -r apikey && read -r secret; do
                    encoded=$(echo -n "$apikey:$secret" | base64 | tr -d '[:space:]')
                    varname="Twitter_cred_$i"
                    eval "$varname=\"$encoded\""
                    #echo "$varname=${!varname}"
                    i=$((i+1))
                  done <<< "$Twitter_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="Twitter_cred_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://api.twitter.com/oauth2/token" --data 'grant_type=client_credentials' -H "Accept: application/json" -H "Authorization: Basic $api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} Twitter${NC} ${YELLOW}API key : Secret${NC} = ${BLUE}$(echo -n "$api_key" | base64 -d)${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} Twitter${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi     
   #URLScan  
    URLScan_api_keys=$(yq eval '.datasources[] | select(.name == "URLScan") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$URLScan_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="URLScan_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$URLScan_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="URLScan_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://urlscan.io/user/quotas/" -H "API-Key: $api_key" -H "Content-Type: application/json" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "400" ] || [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} URLScan${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                      elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} URLScan${NC}"
                           export URLSCANIO_API_KEY="$api_key" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s urlscan   
                           echo -e "\n"                           
                     fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} URLScan${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #VirusTotal  
    VirusTotal_api_keys=$(yq eval '.datasources[] | select(.name == "VirusTotal") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$VirusTotal_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="VirusTotal_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$VirusTotal_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="VirusTotal_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://www.virustotal.com/api/v3/ip_addresses/1.1.1.1" -H "x-apikey: $api_key" -H "Content-Type: application/json" -H "Accept: application/json")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} VirusTotal${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif [ "$status_code" = "429" ]; then
                        echo -e "ⓘ ${VIOLET} VirusTotal${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED} Quota Exceeded${NC}"
                       invalid_key_found=true
                     fi 
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} VirusTotal${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #WhoisXML  
    WhoisXML_api_keys=$(yq eval '.datasources[] | select(.name == "WhoisXMLAPI") | .creds.account.apikey' $amass_config_parsed | grep -v 'null')
    invalid_key_found=false
          if [ -n "$WhoisXML_api_keys" ]; then
                  i=1
                  while read -r api_key; do
                  var_name="WhoisXML_api_key_$i"
                  eval "$var_name=\"$api_key\""
                  i=$((i+1))
                  done <<< "$WhoisXML_api_keys"
                     #curl
                    for ((j=1; ; j++)); do
                          var_name="WhoisXML_api_key_$j"
                          api_key=${!var_name}
                     if [ -z "$api_key" ]; then
                       break
                     fi
                          response=$(curl -qski "https://user.whoisxmlapi.com/user-service/account-balance?apiKey=$api_key")
                          status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                     if [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                       echo -e "ⓘ ${VIOLET} WhoisXML${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true
                     elif echo "$response" | grep -q '"credits": 0'; then
                       echo -e "ⓘ ${VIOLET} WhoisXML${NC} ${YELLOW}API key${NC} = ${BLUE}$api_key${NC} ${RED}\u2717 Useless${NC} [${PINK}500${NC}/${PURPLE}500 ${RED}USED${NC}]"
                       echo -e "ⓘ  Create a${YELLOW} new Account${NC} : ${BLUE}https://whois.whoisxmlapi.com/signup?lang=en${NC}"
                       invalid_key_found=true                        
                      elif [[ "$status_code" = "200" && -n "$quota" ]]; then                       
                               echo -e "ⓘ ${VIOLET} WhoisXML${NC}"
                               export WHOIS_XML_API_KEY="$api_key" 
                               echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                               python3 "/tmp/aki/bin/apikeybeast.py" -s whoisxmlapi   
                               echo -e "\n"                             
                      fi
              done
              if ! $invalid_key_found; then
                  echo -e "ⓘ ${VIOLET} WhoisXML${NC} : ${GREEN}\u2713${NC}"  
              fi  
         fi
   #Yandex  
     Yandex_api_keys=$(yq eval '.datasources[] | select(.name == "Yandex") | .creds.account' $amass_config_parsed -o json | jq -r '"\(.username):\(.apikey)"' | grep -v 'null')
     invalid_key_found=false
     if [ -n "$Yandex_api_keys" ]; then
              i=1
              while read -r api_key; do
              varname="Yandex_cred_$i"
              eval "$varname=\"$api_key\""
               i=$((i+1))
             done <<< "$Yandex_api_keys"
            # curl
             for ((j=1; ; j++)); do
               var_name="Yandex_cred_$j"
               api_key=${!var_name}
               if [ -z "$api_key" ]; then
                break
                fi
                  response=$(curl --ipv4 -qski "https://yandex.com/search/xml?user=$(echo $api_key | awk -F ':' '{print $1}')&key=$(echo $api_key | awk -F ':' '{print $2":"$3}')&query=example")
                  status_code=$(echo "$response" | awk '/HTTP/{print $2}')
                 if echo "$response" | grep -q "Request limit reached"; then
                       echo -e "ⓘ ${VIOLET} Yandex${NC} ${YELLOW}Username : apikey${NC} = ${BLUE}${api_key}${NC} ${RED}\u2717 Limit Reached${NC}"
                       invalid_key_found=true
                 elif echo "$response" | grep -q "list of permitted IP addresses"; then
                       echo -e "ⓘ ${VIOLET} Yandex${NC} ${YELLOW}Username : apikey${NC} = ${BLUE}${api_key}${NC} ${RED}\u2717 IpAddr mismatch${NC}"                       
                       echo -e "ⓘ  Change your ${YELLOW}IP${NC} here: ${BLUE}https://xml.yandex.com/settings/ ${NC}"                       
                       invalid_key_found=true                 
                 elif echo "$response" | grep -q "Invalid key"; then
                       echo -e "ⓘ ${VIOLET} Yandex${NC} ${YELLOW}Username : apikey${NC} = ${BLUE}${NC}${api_key} ${RED}\u2717 Invalid${NC}"
                       invalid_key_found=true                 
                  fi
             done
         if ! $invalid_key_found; then
            echo -e "ⓘ ${VIOLET} Yandex${NC} : ${GREEN}\u2713${NC}"  
         fi  
      fi  
# yq eval '.datasources[] | select(.name == "ZETAlytics") | .creds.account.apikey' $amass_config_parsed | grep -v 'null'        
   #ZoomEye  
     ZoomEye_api_keys=$(yq eval '.datasources[] | select(.name == "ZoomEye") | .creds.account' $amass_config_parsed -o json | jq -r '"\(.username):\(.password)"' | grep -v 'null')
     invalid_key_found=false
     if [ -n "$ZoomEye_api_keys" ]; then
              i=1
              while read -r api_key; do
              varname="ZoomEye_cred_$i"
              eval "$varname=\"$api_key\""
               i=$((i+1))
             done <<< "$ZoomEye_api_keys"
            # curl
             for ((j=1; ; j++)); do
               var_name="ZoomEye_cred_$j"
               api_key=${!var_name}
               if [ -z "$api_key" ]; then
                break
                fi
              response=$(curl -qski "https://api.zoomeye.org/user/login" -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"username\":\"${api_key%:*}\", \"password\":\"${api_key#*:}\"}")
              status_code=$(echo "$response" | awk '/HTTP/{print $2}')
              if [ "$status_code" = "423" ] || [ "$status_code" = "401" ] || [ "$status_code" = "403" ]; then
                  echo -e "ⓘ ${VIOLET} ZoomEye${NC} ${YELLOW}Username:Password${NC} = ${BLUE}${api_key}${NC} ${RED}\u2717 Invalid${NC}"
                  invalid_key_found=true
              elif [[ "$status_code" = "200" && -n "$quota" ]]; then
                          echo -e "ⓘ ${VIOLET} ZoomEye${NC}"
                           export ZOOMEYE_USERNAME="${api_key%:*}"
                           export ZOOMEYE_PASSWORD="${api_key#*:}" 
                           echo -e "${YELLOW}API key${NC} : ${PURPLE}$api_key${NC}"                            
                           python3 "/tmp/aki/bin/apikeybeast.py" -s zoomeye   
                           echo -e "\n"                           
               fi
            done
         if ! $invalid_key_found; then
            echo -e "ⓘ ${VIOLET} ZoomEye${NC} : ${GREEN}\u2713${NC}"  
         fi  
      fi
#EOF amass    
fi
#############
#Cleanup Vars for subfinder's Quota
unset_variables() {
                     unset CENSYS_USERNAME
                     unset unset CENSYS_AUTH
                     unset BINARY_EDGE_USERNAME
                     unset BINARY_EDGE_API_KEY
                     unset BUILT_WITH_USERNAME
                     unset BUILT_WITH_API_KEY
                     unset FullHunt_USERNAME
                     unset FullHunt_API_KEY
                     unset HUNTER_USER
                     unset HUNTER_API_KEY
                     unset INTELX_USERNAME
                     unset INTELX_API_KEY
                     unset IPINFO_USERNAME
                     unset IPINFO_API_KEY
                     unset NETWORKS_DB_USERNAME
                     unset NETWORKS_DB_API_KEY
                     unset ONYPHE_USERNAME
                     unset ONYPHE_API_KEY
                     unset PASSIVE_TOTAL_USERNAME
                     unset PASSIVE_TOTAL_API_KEY
                     unset SECURITY_TRAILS_USERNAME
                     unset SECURITY_TRAILS_API_KEY
                     unset SHODAN_USERNAME
                     unset SHODAN_API_KEY
                     unset URLSCANIO_USERNAME
                     unset URLSCANIO_API_KEY
                     unset WHOIS_XML_API_USERNAME
                     unset WHOIS_XML_API_KEY
                     unset ZOOMEYE_USERNAME
                     unset ZOOMEYE_PASSWORD
}
unset_variables
#EOF