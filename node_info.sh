#!/bin/bash
# Default variables
language="EN"
raw_output="false"

# Options
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/colors.sh) --
option_value(){ echo $1 | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
	case "$1" in
	-h|--help)
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/logo.sh)
		echo
		echo -e "${C_LGn}Functionality${RES}: the script shows information about a Kusama node"
		echo
		echo -e "Usage: script ${C_LGn}[OPTIONS]${RES}"
		echo
		echo -e "${C_LGn}Options${RES}:"
		echo -e "  -h, --help               show help page"
		echo -e "  -l, --language LANGUAGE  use the LANGUAGE for texts"
		echo -e "                           LANGUAGE is '${C_LGn}EN${RES}' (default), '${C_LGn}RU${RES}'"
		echo -e "  -ro, --raw-output        the raw JSON output"
		echo
		echo -e "You can use either \"=\" or \" \" as an option and value ${C_LGn}delimiter${RES}"
		echo
		echo -e "${C_LGn}Useful URLs${RES}:"
		echo -e "https://github.com/SecorD0/Kusama/blob/main/node_info.sh - script URL"
		echo -e "         (you can send Pull request with new texts to add a language)"
		echo -e "https://t.me/letskynode — node Community"
		echo -e "https://teletype.in/@letskynode — guides and articles"
		echo
		return 0 2>/dev/null; exit 0
		;;
	-l*|--language*)
		if ! grep -q "=" <<< $1; then shift; fi
		language=`option_value $1`
		shift
		;;
	-ro|--raw-output)
		raw_output="true"
		shift
		;;
	*|--)
		break
		;;
	esac
done

# Config
using_docker="true"
software_name="kusama_node"

# Functions
printf_n(){ printf "$1\n" "${@:2}"; }
api_request() { wget -qO- -t 1 -T 5 --header "Content-Type: application/json" --post-data '{"id":1, "jsonrpc":"2.0", "method": "'$1'"}' "http://localhost:$2/" | jq; }
main() {
	# Texts
	if [ "$language" = "RU" ]; then
		local t_nn="\nНазвание ноды:               ${C_LGn}%s${RES}"
		local t_nv="Версия ноды:                 ${C_LGn}%s${RES}"
		
		local t_net="\nСеть:                        ${C_LGn}%s${RES}"
		local t_ni=" ID ноды:                    ${C_LGn}%s${RES}"
		local t_lb=" Последний блок:             ${C_LGn}%d${RES}"
		local t_sy1=" Нода синхронизирована:      ${C_LR}нет${RES}"
		local t_sy2=" Осталось нагнать:           ${C_LR}%d-%d=%d (около %.2f мин.)${RES}"
		local t_sy3=" Нода синхронизирована:      ${C_LGn}да${RES}"
		
	# Send Pull request with new texts to add a language - https://github.com/SecorD0/Kusama/blob/main/node_info.sh
	#elif [ "$language" = ".." ]; then
	else
		local t_nn="\nMoniker:                  ${C_LGn}%s${RES}"
		local t_nv="Node version:             ${C_LGn}%s${RES}"
		
		local t_net="\nNetwork:                  ${C_LGn}%s${RES}"
		local t_ni=" Node ID:                 ${C_LGn}%s${RES}"
		local t_lb=" Latest block height:     ${C_LGn}%s${RES}"
		local t_sy1=" Node is synchronized:    ${C_LR}no${RES}"
		local t_sy2=" It remains to catch up:  ${C_LR}%d-%d=%d (about %.2f min.)${RES}"
		local t_sy3=" Node is synchronized:    ${C_LGn}yes${RES}"
	fi

	# Actions
	sudo apt install jq bc -y &>/dev/null
	if [ "$using_docker" = "true" ]; then
		local moniker=`docker logs "$software_name" | grep Node | tail -1 | awk '{ printf $(NF-1) }'`
	else
		local moniker=`sudo journalctl -fn 100 -u "$software_name" | grep Node | tail -1 | awk '{ printf $(NF-1) }'`
	fi
	local node_version=`api_request system_version 9933 | jq -r ".result"`
	
	local network=`api_request system_chain 9933 | jq -r ".result"`
	local node_id=`api_request system_localPeerId 9933 | jq -r ".result"`
	local latest_block_height=`api_request system_syncState 9933 | jq -r ".result.currentBlock"`
	local catching_up=`api_request system_health 9933 | jq -r ".result.isSyncing"`
	
	# Output
	if [ "$raw_output" = "true" ]; then
		printf_n '[{"moniker": "%s", "node_version": "%s", "networks": [{"network": "%s", "node_id": "%s", "latest_block_height": %d, "catching_up": %b}]}]' \
"$moniker" \
"$node_version" \
"$network" \
"$node_id" \
"$latest_block_height" \
"$catching_up"
	else
		printf_n "$t_nn" "$moniker"
		printf_n "$t_nv" "$node_version"
		
		printf_n "$t_net" "$network"
		printf_n "$t_ni" "$node_id"
		printf_n "$t_lb" "$latest_block_height"
		if [ "$catching_up" = "true" ]; then
			local current_block=`api_request system_syncState 9933 | jq ".result.highestBlock"`
			local diff=`bc -l <<< "$current_block-$latest_block_height"`
			local takes_time=`bc -l <<< "$diff/180/60"`
			printf_n "$t_sy1"
			printf_n "$t_sy2" "$current_block" "$latest_block_height" "$diff" "$takes_time"		
		else
			printf_n "$t_sy3"
		fi
		printf_n
	fi
}

main
