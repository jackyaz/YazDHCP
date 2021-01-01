<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>LAN - DHCP Server - Enhanced by YazDHCP</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<link rel="stylesheet" type="text/css" href="device-map/device-map.css">
<style>
thead.collapsible-jquery {
  color: white;
  padding: 0px;
  width: 100%;
  border: none;
  text-align: left;
  outline: none;
  cursor: pointer;
}
</style>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/jquery.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/d3.js"></script>
<script language="JavaScript" type="text/javascript" src="/state.js"></script>
<script language="JavaScript" type="text/javascript" src="/general.js"></script>
<script language="JavaScript" type="text/javascript" src="/popup.js"></script>
<script language="JavaScript" type="text/javascript" src="/help.js"></script>
<script language="JavaScript" type="text/javascript" src="/ext/shared-jy/detect.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmhist.js"></script>
<script language="JavaScript" type="text/javascript" src="/tmmenu.js"></script>
<script language="JavaScript" type="text/javascript" src="/client_function.js"></script>
<script language="JavaScript" type="text/javascript" src="/validator.js"></script>
<script language="JavaScript" type="text/javascript" src="/base64.js"></script>
<script language="JavaScript" type="text/javascript" src="/js/httpApi.js"></script>
<script>
var custom_settings;
function LoadCustomSettings(){
	custom_settings = <% get_custom_settings(); %>;
	for (var prop in custom_settings){
		if (Object.prototype.hasOwnProperty.call(custom_settings, prop)){
			if(prop.indexOf("YazDHCP") != -1 && prop.indexOf("YazDHCP_version") == -1){
				eval("delete custom_settings."+prop)
			}
		}
	}
}

$(function (){
	if(amesh_support && (isSwMode("rt") || isSwMode("ap")) && ameshRouter_support){
		addNewScript('/require/modules/amesh.js');
	}
});

var vpnc_dev_policy_list_array = [];
var vpnc_dev_policy_list_array_ori = [];

var dhcp_staticlist_array = [];
var manually_dhcp_list_array = [];
var manually_dhcp_list_array_ori = [];

if(pptpd_support){
	var pptpd_clients = '<% nvram_get("pptpd_clients"); %>';
	var pptpd_clients_subnet = pptpd_clients.split(".")[0]+"." + pptpd_clients.split(".")[1]+"." + pptpd_clients.split(".")[2]+".";
	var pptpd_clients_start_ip = parseInt(pptpd_clients.split(".")[3].split("-")[0]);
	var pptpd_clients_end_ip = parseInt(pptpd_clients.split("-")[1]);
}

var dhcp_enable = '<% nvram_get("dhcp_enable_x"); %>';
var pool_start = '<% nvram_get("dhcp_start"); %>';
var pool_end = '<% nvram_get("dhcp_end"); %>';
var pool_subnet = pool_start.split(".")[0] + "."+pool_start.split(".")[1] + "."+pool_start.split(".")[2]+".";
var pool_start_end = parseInt(pool_start.split(".")[3]);
var pool_end_end = parseInt(pool_end.split(".")[3]);

var static_enable = '<% nvram_get("dhcp_static_x"); %>';

var dhcp_hostnames_array = [];
var manually_dhcp_hosts_array = [];

var lan_domain_ori = '<% nvram_get("lan_domain"); %>';
var dhcp_gateway_ori = '<% nvram_get("dhcp_gateway_x"); %>';
var dhcp_dns1_ori = '<% nvram_get("dhcp_dns1_x"); %>';
var dhcp_wins_ori = '<% nvram_get("dhcp_wins_x"); %>';

if(yadns_support){
	var yadns_enable = '<% nvram_get("yadns_enable_x"); %>';
	var yadns_mode = '<% nvram_get("yadns_mode"); %>';
}

var backup_mac = "";
var backup_ip = "";
var backup_dns = "";
var backup_name = "";
var sortfield, sortdir;
var sorted_array = [];

function initial(){
	show_menu();
	LoadCustomSettings();
	ScriptUpdateLayout();
	AddEventHandlers();
	//id="faq" href="https://www.asus.com/US/support/FAQ/1036677"
	httpApi.faqURL("1036677", function(url){document.getElementById("faq").href=url;});
	
	d3.csv("/ext/YazDHCP/DHCP_clients.htm").then(function(data){
		if(data.length > 0){
			dhcp_hostnames_array = data.map(function(obj) {
				return {
					MAC: obj.MAC,
					HOSTNAME: obj.HOSTNAME
				}
			});
			
			for(var i = 0; i < dhcp_hostnames_array.length; i++){
				var item_para = {"hostname" : dhcp_hostnames_array[i].HOSTNAME};
				manually_dhcp_hosts_array[dhcp_hostnames_array[i].MAC] = item_para;
			}
			
			dhcp_staticlist_array = data.map(function(obj) {
				return {
					MAC: obj.MAC,
					IP: obj.IP,
					DNS: obj.DNS
				}
			});
			
			for(var i = 0; i < dhcp_staticlist_array.length; i++){
				var item_para = {
					"mac" : dhcp_staticlist_array[i].MAC.toUpperCase(),
					"dns" : dhcp_staticlist_array[i].DNS,
					"hostname" : (manually_dhcp_hosts_array[dhcp_staticlist_array[i].MAC] == undefined) ? "" : manually_dhcp_hosts_array[dhcp_staticlist_array[i].MAC].hostname,
					"ip" : dhcp_staticlist_array[i].IP
				};
				manually_dhcp_list_array[dhcp_staticlist_array[i].IP] = item_para;
				manually_dhcp_list_array_ori[dhcp_staticlist_array[i].IP] = item_para;
			}
		}
		
		showtext(document.getElementById("LANIP"), '<% nvram_get("lan_ipaddr"); %>');
		if((inet_network(document.form.lan_ipaddr.value) >= inet_network(document.form.dhcp_start.value)) && (inet_network(document.form.lan_ipaddr.value) <= inet_network(document.form.dhcp_end.value))){
				document.getElementById('router_in_pool').style.display="";
		}
		else if(dhcp_staticlist_array.length > 0){
			for(var i = 0; i < dhcp_staticlist_array.length; i++){
				var static_ip = dhcp_staticlist_array[i].IP;
				if(static_ip == document.form.lan_ipaddr.value){
					document.getElementById('router_in_pool').style.display="";
				}
			}
		}
		
		if(((sortfield = cookie.get('dhcp_sortcol')) != null) && ((sortdir = cookie.get('dhcp_sortmet')) != null)){
			sortfield = parseInt(sortfield);
			sortdir = parseInt(sortdir) * -1;
		}
		else{
			sortfield = 1;
			sortdir = -1;
		}
		sortlist(sortfield);
		
		setTimeout(showdhcp_staticlist, 100);
		setTimeout("showDropdownClientList('setClientIP', 'mac>ip', 'all', 'ClientList_Block_PC', 'pull_arrow', 'all');", 1000);
		
		if(pptpd_support){
			var chk_vpn = check_vpn();
			if(chk_vpn == true){
				document.getElementById("VPN_conflict").style.display = "";
				document.getElementById("VPN_conflict_span").innerHTML = "* In conflict with the VPN server settings:" + pptpd_clients;
			}
		}
	});
	
	if(yadns_support){
		if(yadns_enable != 0 && yadns_mode != -1){
			document.getElementById("yadns_hint").style.display = "";
			document.getElementById("yadns_hint").innerHTML = "<span>Clients are using Yandex.DNS regardless of the DNS setting.</span>";
		}
	}
	
	document.form.sip_server.disabled = true;
	document.form.sip_server.parentNode.parentNode.style.display = "none";
	
	if(vpn_fusion_support){
		vpnc_dev_policy_list_array = parse_vpnc_dev_policy_list('<% nvram_char_to_ascii("","vpnc_dev_policy_list"); %>');
		vpnc_dev_policy_list_array_ori = vpnc_dev_policy_list_array.slice();
	}
	
	if(lyra_hide_support){
		$("#dhcpEnable").hide();
	}
}

function ScriptUpdateLayout(){
	var localver = GetVersionNumber("local");
	var serverver = GetVersionNumber("server");
	$("#yazdhcp_version_local").text(localver);
	
	if (localver != serverver && serverver != "N/A"){
		$("#yazdhcp_version_server").text("Updated version available: "+serverver);
		showhide("btnChkUpdate", false);
		showhide("yazdhcp_version_server", true);
		showhide("btnDoUpdate", true);
	}
}

function reload(){
	location.reload(true);
}

function update_status(){
	$.ajax({
		url: '/ext/yazdhcp/detect_update.js',
		dataType: 'script',
		timeout: 3000,
		error: function(xhr){
			setTimeout(update_status, 1000);
		},
		success: function(){
			if (updatestatus == "InProgress"){
				setTimeout(update_status, 1000);
			}
			else{
				document.getElementById("imgChkUpdate").style.display = "none";
				showhide("yazdhcp_version_server", true);
				if(updatestatus != "None"){
					$("#yazdhcp_version_server").text("Updated version available: "+updatestatus);
					showhide("btnChkUpdate", false);
					showhide("btnDoUpdate", true);
				}
				else{
					$("#yazdhcp_version_server").text("No update available");
					showhide("btnChkUpdate", true);
					showhide("btnDoUpdate", false);
				}
			}
		}
	});
}

function CheckUpdate(){
	showhide("btnChkUpdate", false);
	document.formScriptActions.action_script.value="start_yazdhcpcheckupdate"
	document.formScriptActions.submit();
	document.getElementById("imgChkUpdate").style.display = "";
	setTimeout(update_status, 2000);
}

function DoUpdate(){
	var action_script_tmp = "start_yazdhcpdoupdate";
	document.form.action_script.value = action_script_tmp;
	var restart_time = 10;
	document.form.action_wait.value = restart_time;
	showLoading();
	document.form.submit();
}

function GetVersionNumber(versiontype){
	var versionprop;
	if(versiontype == "local"){
		versionprop = custom_settings.yazdhcp_version_local;
	}
	else if(versiontype == "server"){
		versionprop = custom_settings.yazdhcp_version_server;
	}
	
	if(typeof versionprop == 'undefined' || versionprop == null){
		return "N/A";
	}
	else{
		return versionprop;
	}
}

function GetCookie(cookiename,returntype){
	var s;
	if ((s = cookie.get("yazdhcp_"+cookiename)) != null){
		return cookie.get("yazdhcp_"+cookiename);
	}
	else{
		if(returntype == "string"){
			return "";
		}
		else if(returntype == "number"){
			return 0;
		}
	}
}

function SetCookie(cookiename,cookievalue){
	cookie.set("yazdhcp_"+cookiename, cookievalue, 31);
}

function AddEventHandlers(){
	$(".collapsible-jquery").click(function(){
		$(this).siblings().toggle("fast",function(){
			if($(this).css("display") == "none"){
				SetCookie($(this).siblings()[0].id,"collapsed");
			}
			else{
				SetCookie($(this).siblings()[0].id,"expanded");
			}
		})
	});
	
	$(".collapsible-jquery").each(function(index,element){
		if(GetCookie($(this)[0].id,"string") == "collapsed"){
			$(this).siblings().toggle(false);
		}
		else{
			$(this).siblings().toggle(true);
		}
	});
}

function addRow_Group(upper){
	if(dhcp_enable != "1"){
		document.form.dhcp_enable_x[0].checked = true
	}
	if(static_enable != "1"){
		document.form.dhcp_static_x[0].checked = true
	}
		
	var rule_num = Object.keys(manually_dhcp_list_array).length;
	if(rule_num >= upper){
		alert("This table only allows " + upper + " items!");
		return false;
	}
	
	if(document.form.dhcp_staticmac_x_0.value==""){
		alert("Fields cannot be blank.");
		document.form.dhcp_staticmac_x_0.focus();
		document.form.dhcp_staticmac_x_0.select();
		return false;
	}
	else if(document.form.dhcp_staticip_x_0.value==""){
		alert("Fields cannot be blank.");
		document.form.dhcp_staticip_x_0.focus();
		document.form.dhcp_staticip_x_0.select();
		return false;
	}
	else if((document.form.dhcp_staticname_x_0.value != "") && ((alert_str = validator.host_name(document.form.dhcp_staticname_x_0)) != "")){
		alert(alert_str);
		document.form.dhcp_staticname_x_0.focus();
		document.form.dhcp_staticname_x_0.select();
		return false;
	}
	else if(check_macaddr(document.form.dhcp_staticmac_x_0, check_hwaddr_flag(document.form.dhcp_staticmac_x_0, 'inner')) == true
				&& validator.validIPForm(document.form.dhcp_staticip_x_0,0) == true && validate_dhcp_range(document.form.dhcp_staticip_x_0) == true){
					if(document.form.dhcp_dnsip_x_0.value != ""){
						if(!validator.ipAddrFinal(document.form.dhcp_dnsip_x_0, 'dhcp_dns1_x')){
							return false;
						}
					}
		//match(ip or mac) is not accepted
		var match_flag = false;
		for(var key in manually_dhcp_list_array){
			if(manually_dhcp_list_array.hasOwnProperty(key)){
				var exist_ip = key;
				var exist_mac = manually_dhcp_list_array[exist_ip].mac;
				if(exist_mac == document.form.dhcp_staticmac_x_0.value.toUpperCase()){
					alert("This entry already exists.");
					document.form.dhcp_staticmac_x_0.focus();
					document.form.dhcp_staticmac_x_0.select();
					match_flag = true;
					break;
				}
				if(exist_ip == document.form.dhcp_staticip_x_0.value){
					alert("This entry already exists.");
					document.form.dhcp_staticip_x_0.focus();
					document.form.dhcp_staticip_x_0.select();
					match_flag = true;
					break;
				}
			}
		}
		if(match_flag) return false;
		
		var item_para = {
			"mac" : document.form.dhcp_staticmac_x_0.value.toUpperCase(),
			"dns" : document.form.dhcp_dnsip_x_0.value,
			"hostname" : document.form.dhcp_staticname_x_0.value,
			"ip" : document.form.dhcp_staticip_x_0.value
		};
			
		manually_dhcp_list_array[document.form.dhcp_staticip_x_0.value.toUpperCase()] = item_para;
		
		if(vpn_fusion_support){
			var newRuleArray = [];
			newRuleArray.push(document.form.dhcp_staticip_x_0.value);
			newRuleArray.push("0");
			newRuleArray.push("0");
			vpnc_dev_policy_list_array.push(newRuleArray);
		}
		
		document.form.dhcp_staticip_x_0.value = "";
		document.form.dhcp_staticmac_x_0.value = "";
		document.form.dhcp_dnsip_x_0.value = "";
		document.form.dhcp_staticname_x_0.value = "";
		
		sortdir = sortdir * -1;	/* sortlist() will switch order back */
		sortlist(sortfield);
		showdhcp_staticlist();
		
		if(backup_mac != ""){
			backup_mac = "";
			backup_ip = "";
			backup_dns = "";
			backup_name = "";
			document.getElementById('dhcp_staticlist_table').rows[rule_num-1].scrollIntoView();
		}
	}
	else{
		return false;
	}
}

function del_Row(r){
	var i = r.parentNode.parentNode.rowIndex;
	var delIP = document.getElementById('dhcp_staticlist_table').rows[i].cells[1].innerHTML;
	
	if(vpn_fusion_support){
		if(manually_dhcp_list_array_ori[delIP] != undefined){
			if(!confirm("Remove the client's IP binding will also delete the client's policy in the exception list of Multiple VPN Connection. Are you sure you want to delete?")){/*untranslated*/
				return false;
			}
		}
	}
	
	delete manually_dhcp_list_array[delIP];
	delete manually_dhcp_hosts_array[delIP];
	document.getElementById('dhcp_staticlist_table').deleteRow(i);
	
	if(Object.keys(manually_dhcp_list_array).length == 0){
		showdhcp_staticlist();
	}
		
	if(vpn_fusion_support){
		for(var i = 0; i < vpnc_dev_policy_list_array.length; i+=1){
			var tmp_array = [];
			for(var i in vpnc_dev_policy_list_array){
				if(vpnc_dev_policy_list_array.hasOwnProperty(i)){
					if(vpnc_dev_policy_list_array[i][0] != delIP){
						tmp_array.push(vpnc_dev_policy_list_array[i]);
					}
				}
			}
			vpnc_dev_policy_list_array = tmp_array;
		}
	}
}

function edit_Row(r){
	cancel_Edit();
	
	var i=r.parentNode.parentNode.rowIndex;
	document.form.dhcp_staticmac_x_0.value = document.getElementById('dhcp_staticlist_table').rows[i].cells[0].title;
	document.form.dhcp_staticip_x_0.value = document.getElementById('dhcp_staticlist_table').rows[i].cells[1].innerHTML;
	if(validator.ipv4_addr(document.getElementById('dhcp_staticlist_table').rows[i].cells[2].innerHTML, 'dhcp_dns1_x')){
		document.form.dhcp_dnsip_x_0.value = document.getElementById('dhcp_staticlist_table').rows[i].cells[2].innerHTML
	}
	document.form.dhcp_staticname_x_0.value = document.getElementById('dhcp_staticlist_table').rows[i].cells[3].title;
	backup_mac = document.form.dhcp_staticmac_x_0.value;
	backup_ip = document.form.dhcp_staticip_x_0.value;
	backup_dns = document.form.dhcp_dnsip_x_0.value;
	backup_name = document.form.dhcp_staticname_x_0.value;
	del_Row(r);
	document.form.dhcp_staticmac_x_0.focus();
}

function cancel_Edit(){
	if(backup_mac != ""){
		document.form.dhcp_staticmac_x_0.value = backup_mac;
		document.form.dhcp_staticip_x_0.value = backup_ip;
		document.form.dhcp_dnsip_x_0.value = backup_dns;
		document.form.dhcp_staticname_x_0.value = backup_name;
		addRow_Group(64);
	}
}

function showdhcp_staticlist(){
	var code = "";
	var clientListEventData = [];
	code+='<table width="100%" cellspacing="0" cellpadding="4" align="center" class="list_table" id="dhcp_staticlist_table">';
	if(Object.keys(manually_dhcp_list_array).length == 0){
		code+='<tr><td style="color:#FFCC00;">No data in table.</td></tr>';
	}
	else{
		//user icon
		var userIconBase64 = "NoIcon";
		var clientName, deviceType, deviceVender;
		
		for(var i = 0; i < sorted_array.length; i++){
			var key = sorted_array[i].ip;
			var clientMac = manually_dhcp_list_array[key]["mac"].toUpperCase();
			var clientDNS = manually_dhcp_list_array[key]["dns"];
			if(clientDNS == ""){
				clientDNS = "Default";
			}
			var clientIconID = "clientIcon_" + clientMac.replace(/\:/g, "");
			var clientIP = key;
			if(clientList[clientMac]){
				clientName = (clientList[clientMac].nickName == "") ? clientList[clientMac].name : clientList[clientMac].nickName;
				deviceType = clientList[clientMac].type;
				deviceVender = clientList[clientMac].vendor;
			}
			else{
				clientName = "New device";
				deviceType = 0;
				deviceVender = "";
			}
			if(manually_dhcp_list_array[key] != undefined){
				var clientHostname = manually_dhcp_list_array[key].hostname;
			}
			else{
				var clientHostname = "";
			}
			
			code+='<tr><td width="32%" align="center" title="' + clientMac +'">';
			code+='<table style="width:100%;"><tr><td style="width:40%;height:56px;border:0px;">';
			if(clientList[clientMac] == undefined){
				code+='<div id="' + clientIconID + '" class="clientIcon type0"></div>';
			}
			else{
				if(usericon_support){
					userIconBase64 = getUploadIcon(clientMac.replace(/\:/g, ""));
				}
				if(userIconBase64 != "NoIcon"){
					code+='<div id="' + clientIconID + '" style="text-align:center;"><img class="imgUserIcon_card" src="' + userIconBase64 + '"></div>';
				}
				else if(deviceType != "0" || deviceVender == ""){
					code+='<div id="' + clientIconID + '" class="clientIcon type' + deviceType + '"></div>';
				}
				else if(deviceVender != "" ){
					var venderIconClassName = getVenderIconClassName(deviceVender.toLowerCase());
					if(venderIconClassName != "" && !downsize_4m_support){
						code+='<div id="' + clientIconID + '" class="venderIcon ' + venderIconClassName + '"></div>';
					}
					else{
						code+='<div id="' + clientIconID + '" class="clientIcon type' + deviceType + '"></div>';
					}
				}
			}
			code+='</td><td style="width:60%;border:0px;">';
			code+='<div>' + clientName + '</div>';
			code+='<div>' + clientMac + '</div>';
			code+='</td></tr></table>';
			code+='</td>';
			code+='<td width="19%">'+ clientIP +'</td>';
			code+='<td width="19%">'+ clientDNS +'</td>';
			if(clientHostname.length > 21){
				code+='<td width="23%" title="'+ clientHostname +'">' + clientHostname.substring(0,18) +'...</td>';
			}
			else{
				code+='<td width="23%" title="'+ clientHostname +'">'+ clientHostname +'</td>';
			}
			code+='<td width="7%">';
			code+='<input class="edit_btn" onclick="edit_Row(this);" value=""/>';
			code+='<input class="remove_btn" onclick="del_Row(this);" value=""/></td></tr>';
			if(validator.mac_addr(clientMac)){
				clientListEventData.push({"mac" : clientMac, "name" : clientName, "ip" : clientIP, "callBack" : "DHCP"});
			}
		}
	}
	code+='</table>';
	document.getElementById("dhcp_staticlist_Block").innerHTML = code;
	for(var i = 0; i < clientListEventData.length; i+=1){
		var clientIconID = "clientIcon_" + clientListEventData[i].mac.replace(/\:/g, "");
		var clientIconObj = $("#dhcp_staticlist_Block").children("#dhcp_staticlist_table").find("#" + clientIconID + "")[0];
		var paramData = JSON.parse(JSON.stringify(clientListEventData[i]));
		paramData["obj"] = clientIconObj;
		$("#dhcp_staticlist_Block").children("#dhcp_staticlist_table").find("#" + clientIconID + "").click(paramData, popClientListEditTable);
	}
}

function applyRule(){
	cancel_Edit();
	
	if(validForm()){
		dhcp_staticlist_array = [];
		dhcp_hostnames_array = [];
		
		Object.keys(manually_dhcp_list_array).forEach(function(key){
			if(manually_dhcp_list_array[key].dns.length > 0){
				document.form.YazDHCP_clients.value += "<" + manually_dhcp_list_array[key].mac + ">" + key + ">" + manually_dhcp_list_array[key].hostname + ">" + manually_dhcp_list_array[key].dns + ">";
			}
			else{
				document.form.YazDHCP_clients.value += "<" + manually_dhcp_list_array[key].mac + ">" + key + ">" + manually_dhcp_list_array[key].hostname + ">";
			}
		});
		
		document.form.YazDHCP_clients.value = document.form.YazDHCP_clients.value.slice(0, -1).replace(/:/g,'|');
		
		if(document.form.YazDHCP_clients.value.length > 6498){
			alert("DHCP reservation list is too long (" + document.form.YazDHCP_clients.value.length + " characters exceeds limit of 6498)\r\nRemove some, or use shorter names.");
			return false;
		}
		else if(document.form.YazDHCP_clients.value.length > 2999 && document.form.YazDHCP_clients.value.length <= 5998){
			var yazdhcp_settings = document.form.YazDHCP_clients.value.match(/.{1,2999}/g);
			custom_settings["yazdhcp_clients"] = yazdhcp_settings[0];
			custom_settings["yazdhcp_clients2"] = yazdhcp_settings[1];
		}
		else if(document.form.YazDHCP_clients.value.length > 5998 && document.form.YazDHCP_clients.value.length <= 6498){
			var yazdhcp_settings = document.form.YazDHCP_clients.value.match(/.{1,2999}/g);
			custom_settings["yazdhcp_clients"] = yazdhcp_settings[0];
			custom_settings["yazdhcp_clients2"] = yazdhcp_settings[1];
			custom_settings["yazdhcp_clients3"] = yazdhcp_settings[2];
		}
		else{
			custom_settings["yazdhcp_clients"] = document.form.YazDHCP_clients.value;
		}
		
		document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
		
		// Only restart the whole network if needed
		if ((document.form.dhcp_wins_x.value != dhcp_wins_ori) ||
				(document.form.dhcp_dns1_x.value != dhcp_dns1_ori) ||
				(document.form.dhcp_gateway_x.value != dhcp_gateway_ori) ||
				(document.form.lan_domain.value != lan_domain_ori)){
					document.form.action_script.value = "restart_net_and_phy";
		}
		else{
			document.form.action_script.value = "restart_dnsmasq";
			document.form.action_wait.value = 5;
		}
		
		var action_script_tmp = "start_YazDHCP;" + document.form.action_script.value;
		document.form.action_script.value = action_script_tmp;
		
		if(vpn_fusion_support){
			if(vpnc_dev_policy_list_array.toString() != vpnc_dev_policy_list_array_ori.toString()){
				var action_script_tmp = "restart_vpnc_dev_policy;" + document.form.action_script.value;
				document.form.action_script.value = action_script_tmp;
				
				var parseArrayToStr_vpnc_dev_policy_list = function(_array){
					var vpnc_dev_policy_list = "";
					for(var i = 0; i < _array.length; i+=1){
						if(_array[i].length != 0){
							if(i != 0){
								vpnc_dev_policy_list+="<";
							}
							var temp_ipaddr = _array[i][0];
							var temp_vpnc_idx = _array[i][1];
							var temp_active = _array[i][2];
							var temp_destination_ip = "";
							vpnc_dev_policy_list+=temp_active + ">" + temp_ipaddr + ">" + temp_destination_ip + ">" + temp_vpnc_idx;
						}
					}
					return vpnc_dev_policy_list;
				};
				
				document.form.vpnc_dev_policy_list.disabled = false;
				document.form.vpnc_dev_policy_list_tmp.disabled = false;
				document.form.vpnc_dev_policy_list_tmp.value = parseArrayToStr_vpnc_dev_policy_list(vpnc_dev_policy_list_array_ori);
				document.form.vpnc_dev_policy_list.value = parseArrayToStr_vpnc_dev_policy_list(vpnc_dev_policy_list_array);
			}
		}
		
		if(based_modelid == "MAP-AC1300" || based_modelid == "MAP-AC2200" || based_modelid == "VZW-AC1300" || based_modelid == "MAP-AC1750"){
			alert("By applying new LAN settings, please reboot all Lyras connected to main Lyra manually.");
		}
		
		if(amesh_support && isSwMode("rt") && ameshRouter_support){
			var radio_value = (document.form.dhcp_enable_x[0].checked) ? 1 : 0;
			if(!AiMesh_confirm_msg("DHCP_Server", radio_value)){
				return false;
			}
		}
		
		showLoading();
		document.form.submit();
	}
}

function validate_dhcp_range(ip_obj){
	var ip_num = inet_network(ip_obj.value);
	var subnet_head, subnet_end;
	
	if(ip_num <= 0){
		alert(ip_obj.value+" is not a valid IP address!");
		ip_obj.value = "";
		ip_obj.focus();
		ip_obj.select();
		return 0;
	}
	
	subnet_head = getSubnet(document.form.lan_ipaddr.value, document.form.lan_netmask.value, "head");
	subnet_end = getSubnet(document.form.lan_ipaddr.value, document.form.lan_netmask.value, "end");
	
	if(ip_num <= subnet_head || ip_num >= subnet_end){
		alert(ip_obj.value+" is not a valid IP address!");
		ip_obj.value = "";
		ip_obj.focus();
		ip_obj.select();
		return 0;
	}
	
	return 1;
}

function validForm(){
	var re = new RegExp('^[a-zA-Z0-9][a-zA-Z0-9\.\-]*[a-zA-Z0-9]$','gi');
	if((!re.test(document.form.lan_domain.value) || document.form.lan_domain.value.indexOf("asuscomm.com") > 0) && document.form.lan_domain.value != ""){
		alert("Invalid character!");
		document.form.lan_domain.focus();
		document.form.lan_domain.select();
		return false;
	}
	
	if(!validator.ipAddrFinal(document.form.dhcp_gateway_x, 'dhcp_gateway_x') ||
		!validator.ipAddrFinal(document.form.dhcp_dns1_x, 'dhcp_dns1_x') ||
		!validator.ipAddrFinal(document.form.dhcp_wins_x, 'dhcp_wins_x')){
			return false;
	}
	if(tmo_support && !validator.ipAddrFinal(document.form.sip_server, 'sip_server')){
		return false;
	}
	
	if(!validate_dhcp_range(document.form.dhcp_start) || !validate_dhcp_range(document.form.dhcp_end)){
		return false;
	}
	
	var dhcp_start_num = inet_network(document.form.dhcp_start.value);
	var dhcp_end_num = inet_network(document.form.dhcp_end.value);
	
	if(dhcp_start_num > dhcp_end_num){
		var tmp = document.form.dhcp_start.value;
		document.form.dhcp_start.value = document.form.dhcp_end.value;
		document.form.dhcp_end.value = tmp;
	}
	
	var default_pool = [];
	default_pool = get_default_pool(document.form.lan_ipaddr.value, document.form.lan_netmask.value);
	if((inet_network(document.form.dhcp_start.value) < inet_network(default_pool[0])) || (inet_network(document.form.dhcp_end.value) > inet_network(default_pool[1]))){
		if(confirm("The new IP Pool does not match the subnet mask. Would you like to allow router to change the IP pool automatically?")){ //Acceptable DHCP ip pool : "+default_pool[0]+"~"+default_pool[1]+"\n
			document.form.dhcp_start.value=default_pool[0];
			document.form.dhcp_end.value=default_pool[1];
		}
		else{
			return false;
		}
	}
	
	if(!validator.range(document.form.dhcp_lease, 120, 604800)){
		return false;
	}
	
	//Filtering ip address with leading zero
	document.form.dhcp_start.value = ipFilterZero(document.form.dhcp_start.value);
	document.form.dhcp_end.value = ipFilterZero(document.form.dhcp_end.value);
	return true;
}

function done_validating(action){
	refreshpage();
}

function get_default_pool(ip, netmask){
	z=0;
	tmp_ip=0;
	for(i=0;i<document.form.lan_ipaddr.value.length;i++){
		if(document.form.lan_ipaddr.value.charAt(i) == '.') z++;
		if(z==3){ tmp_ip=i+1; break;}
	}
	post_lan_ipaddr = document.form.lan_ipaddr.value.substr(tmp_ip,3);
	c=0;
	tmp_nm=0;
	for(i=0;i<document.form.lan_netmask.value.length;i++){
		if(document.form.lan_netmask.value.charAt(i) == '.') c++;
		if(c==3){ tmp_nm=i+1; break;}
	}
	var post_lan_netmask = document.form.lan_netmask.value.substr(tmp_nm,3);
	
	var nm = new Array("0", "128", "192", "224", "240", "248", "252");
	for(i=0;i<nm.length;i++){
		if(post_lan_netmask==nm[i]){
			gap=256-Number(nm[i]);
			subnet_set = 256/gap;
			for(j=1;j<=subnet_set;j++){
				if(post_lan_ipaddr < j*gap){
					pool_start=(j-1)*gap+1;
					pool_end=j*gap-2;
					break;
				}
			}
			var default_pool_start = subnetPostfix(document.form.dhcp_start.value, pool_start, 3);
			var default_pool_end = subnetPostfix(document.form.dhcp_end.value, pool_end, 3);
			var default_pool = new Array(default_pool_start, default_pool_end);
			return default_pool;
			break;
		}
	}
}

function setClientIP(macaddr, ipaddr){
	document.form.dhcp_staticmac_x_0.value = macaddr;
	document.form.dhcp_staticip_x_0.value = ipaddr;
	hideClients_Block();
}

function hideClients_Block(){
	document.getElementById("pull_arrow").src = "/images/arrow-down.gif";
	document.getElementById('ClientList_Block_PC').style.display='none';
}

function pullLANIPList(obj){
	var element = document.getElementById('ClientList_Block_PC');
	var isMenuopen = element.offsetWidth > 0 || element.offsetHeight > 0;
	if(isMenuopen == 0){
		obj.src = "/images/arrow-top.gif"
		element.style.display = 'block';
		document.form.dhcp_staticmac_x_0.focus();
	}
	else{
		hideClients_Block();
	}
}

function check_macaddr(obj,flag){ //control hint of input mac address
	if(flag == 1){
		var childsel=document.createElement("div");
		childsel.setAttribute("id","check_mac");
		childsel.style.color="#FFCC00";
		obj.parentNode.appendChild(childsel);
		document.getElementById("check_mac").innerHTML="The format for the MAC address is six groups of two hexadecimal digits, separated by colons (:), in transmission order (e.g. 12:34:56:aa:bc:ef)";
		document.getElementById("check_mac").style.display = "";
		obj.focus();
		obj.select();
		return false;
	}
	else if(flag == 2){
		var childsel=document.createElement("div");
		childsel.setAttribute("id","check_mac");
		childsel.style.color="#FFCC00";
		obj.parentNode.appendChild(childsel);
		document.getElementById("check_mac").innerHTML="MAC address is not valid.";
		document.getElementById("check_mac").style.display = "";
		obj.focus();
		obj.select();
		return false;
	}
	else{
		document.getElementById("check_mac") ? document.getElementById("check_mac").style.display="none" : true;
		return true;
	}
}

function sortlist(field){
	document.getElementById('col' + sortfield).style.boxShadow = "";
	
	if(field == sortfield){
		sortdir = sortdir * -1;
	}
	else{
		sortfield = field;
	}
	
	document.getElementById('col' + sortfield).style.boxShadow = "rgb(255, 204, 0) 0px " + (sortdir == 1 ? "1" : "-1") + "px 0px 0px inset";
	cookie.set('dhcp_sortcol',field);
	cookie.set('dhcp_sortmet',sortdir);
	
	sorted_array = [];
	Object.keys(manually_dhcp_list_array).forEach(function(key){
		sorted_array.push(manually_dhcp_list_array[key]);
	});
	sorted_array.sort(table_sort);
}

function table_sort(a, b){
	var aa, bb, resulta, resultb;
	var isIP = 0;
	
	switch (sortfield){
		case 0:
			if(clientList[a.mac]){
				aa = (clientList[a.mac].nickName == "") ? clientList[a.mac].name : clientList[a.mac].nickName;
			}
			else{
				aa = "";
			}
			if(clientList[b.mac]){
				bb = (clientList[b.mac].nickName == "") ? clientList[b.mac].name : clientList[b.mac].nickName;
			}
			else{
				bb = "";
			}
			isIP = 0;
			break;
		case 1:
			aa = a.ip.split(".");
			bb = b.ip.split(".");
			isIP = 1;
			break;
		case 3:
			aa = a.dns.split(".");
			bb = b.dns.split(".");
			if(aa.length != 4)
				aa = [0,0,0,0];
			if(bb.length != 4)
				bb = [0,0,0,0];
			isIP = 1;
			break;
		case 2:
			aa = a.hostname;
			bb = b.hostname;
			isIP = 0;
			break;
		default: // IP
			aa = a.ip.split(".");
			bb = b.ip.split(".");
			isIP = 1;
			break;
		}

	if(isIP){
		resulta = aa[0]*0x1000000 + aa[1]*0x10000 + aa[2]*0x100 + aa[3]*1;
		resultb = bb[0]*0x1000000 + bb[1]*0x10000 + bb[2]*0x100 + bb[3]*1;
		return (sortdir * (resulta - resultb));
	}
	else{
		resulta = aa.toUpperCase();
		resultb = bb.toUpperCase();
		if(resulta > resultb){
			return (sortdir * 1);
		}
		else if(resulta < resultb){
			return (sortdir * -1);
		}
		else{
			return 0;
		}
	}
}

function check_vpn(){ //true: (DHCP ip pool & static ip ) conflict with VPN clients
		if(pool_subnet == pptpd_clients_subnet
					&& ((pool_start_end >= pptpd_clients_start_ip && pool_start_end <= pptpd_clients_end_ip)
								|| (pool_end_end >= pptpd_clients_start_ip && pool_end_end <= pptpd_clients_end_ip)
								|| (pptpd_clients_start_ip >= pool_start_end && pptpd_clients_start_ip <= pool_end_end)
								|| (pptpd_clients_end_ip >= pool_start_end && pptpd_clients_end_ip <= pool_end_end))
					){
						return true;
		}
		
		if(dhcp_staticlist_array.length > 0){
			for(var i = 0; i < dhcp_staticlist_array.length; i++){
					var static_subnet ="";
					var static_end ="";
					var static_ip = dhcp_staticlist_array[i].IP;
					static_subnet = static_ip.split(".")[0]+"."+static_ip.split(".")[1]+"."+static_ip.split(".")[2]+".";
					static_end = parseInt(static_ip.split(".")[3]);
					if(static_subnet == pptpd_clients_subnet
						&& static_end >= pptpd_clients_start_ip
						&& static_end <= pptpd_clients_end_ip){
							return true;
						}
			}
	}
	
	return false;
}

function parse_vpnc_dev_policy_list(_oriNvram){
	var parseArray = [];
	var oriNvramRow = decodeURIComponent(_oriNvram).split('<');
	for(var i = 0; i < oriNvramRow.length; i+=1){
		if(oriNvramRow[i] != ""){
			var oriNvramCol = oriNvramRow[i].split('>');
			var eachRuleArray = [];
			if(oriNvramCol.length == 4){
				var temp_ipaddr = oriNvramCol[1];
				var temp_vpnc_idx =  oriNvramCol[3];
				var temp_active = oriNvramCol[0];
				eachRuleArray.push(temp_ipaddr);
				eachRuleArray.push(temp_vpnc_idx);
				eachRuleArray.push(temp_active);
			}
			parseArray.push(eachRuleArray);
		}
	}
	return parseArray;
}
</script>
</head>
<body onload="initial();" onunload="return unload_body();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="about:blank" width="0" height="0" frameborder="0"></iframe>
<form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="productid" value="<% nvram_get("productid"); %>">
<input type="hidden" name="current_page" value="Advanced_DHCP_Content.asp">
<input type="hidden" name="next_page" value="Advanced_GWStaticRoute_Content.asp">
<input type="hidden" name="modified" value="0">
<input type="hidden" name="action_mode" value="apply_new">
<input type="hidden" name="action_wait" value="30">
<input type="hidden" name="action_script" value="restart_net_and_phy">
<input type="hidden" name="first_time" value="">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get("preferred_lang"); %>">
<input type="hidden" name="firmver" value="<% nvram_get("firmver"); %>">
<input type="hidden" name="amng_custom" id="amng_custom" value="">
<input type="hidden" name="lan_ipaddr" value="<% nvram_get("lan_ipaddr"); %>">
<input type="hidden" name="lan_netmask" value="<% nvram_get("lan_netmask"); %>">
<input type="hidden" name="YazDHCP_clients" value="">
<input type="hidden" name="vpnc_dev_policy_list" value="" disabled>
<input type="hidden" name="vpnc_dev_policy_list_tmp" value="" disabled>
<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202">
<div id="mainMenu"></div>
<div id="subMenu"></div>
</td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr>
<td align="left" valign="top">
<table width="760" border="0" cellpadding="4" cellspacing="0" class="FormTitle" id="FormTitle">
<tbody>
<tr>
<td bgcolor="#4D595D" valign="top">
<div>&nbsp;</div>
<div class="formfonttitle" id="scripttitle">LAN - DHCP Server - Enhanced by YazDHCP</div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>
<div class="formfontdesc">DHCP (Dynamic Host Configuration Protocol) is a protocol for the automatic configuration used on IP networks. The DHCP server can assign each client an IP address and informs the client of the of DNS server IP and default gateway IP. Router supports up to 253 IP addresses for your local network.</div>
<div id="router_in_pool" class="formfontdesc" style="color:#FFCC00;display:none;">WARNING: The router's IP address is within your pool! <span id="LANIP"></span> </div>
<div id="VPN_conflict" class="formfontdesc" style="color:#FFCC00;display:none;"><span id="VPN_conflict_span"></span></div>
<div class="formfontdesc" style="margin-top:-10px;"><a id="faq" href="" target="_blank" style="font-family:Lucida Console;text-decoration:underline;">Manually Assigned IP around the DHCP list&nbsp;FAQ</a></div>

<table width="100%" border="1" align="center" cellpadding="2" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" style="border:0px;" id="table_buttons">
<thead class="collapsible-jquery" id="scripttools">
<tr><td colspan="2">Utilities (click to expand/collapse)</td></tr>
</thead>
<tr>
<th width="20%">Version information</th>
<td>
<span id="yazdhcp_version_local" style="color:#FFFFFF;"></span>
&nbsp;&nbsp;&nbsp;
<span id="yazdhcp_version_server" style="display:none;">Update version</span>
&nbsp;&nbsp;&nbsp;
<input type="button" class="button_gen" onclick="CheckUpdate();" value="Check" id="btnChkUpdate">
<img id="imgChkUpdate" style="display:none;vertical-align:middle;" src="images/InternetScan.gif"/>
<input type="button" class="button_gen" onclick="DoUpdate();" value="Update" id="btnDoUpdate" style="display:none;">
&nbsp;&nbsp;&nbsp;
</td>
</tr>
</table>
<div style="line-height:10px;">&nbsp;</div>


<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">

<thead><tr><td colspan="2">Basic Config</td></tr></thead>

<tr id="dhcpEnable">
<th><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,1);">Enable the DHCP Server</a></th>
<td>
<input type="radio" value="1" name="dhcp_enable_x" class="content_input_fd" onclick="return change_common_radio(this, 'LANHostConfig', 'dhcp_enable_x', '1')" <% nvram_match("dhcp_enable_x", "1", "checked"); %>>Yes
<input type="radio" value="0" name="dhcp_enable_x" class="content_input_fd" onclick="return change_common_radio(this, 'LANHostConfig', 'dhcp_enable_x', '0')" <% nvram_match("dhcp_enable_x", "0", "checked"); %>>No
</td>
</tr>

<tr>
<th>Hide DHCP/RA queries</th>
<td>
<input type="radio" value="0" name="dhcpd_querylog" class="content_input_fd" onclick="return change_common_radio(this, 'LANHostConfig', 'dhcpd_querylog', '0')" <% nvram_match("dhcpd_querylog", "0", "checked"); %>>Yes
<input type="radio" value="1" name="dhcpd_querylog" class="content_input_fd" onclick="return change_common_radio(this, 'LANHostConfig', 'dhcpd_querylog', '1')" <% nvram_match("dhcpd_querylog", "1", "checked"); %>>No
</td>
</tr>

<tr>
<th><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,2);">Router's Domain Name</a></th>
<td>
<input type="text" maxlength="32" class="input_25_table" name="lan_domain" value="<% nvram_get("lan_domain"); %>" autocorrect="off" autocapitalize="off">
</td>
</tr>

<tr>
<th><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,3);">IP Pool Starting Address</a></th>
<td>
<input type="text" maxlength="15" class="input_15_table" name="dhcp_start" value="<% nvram_get("dhcp_start"); %>" onKeyPress="return validator.isIPAddr(this,event);" autocorrect="off" autocapitalize="off">
</td>
</tr>

<tr>
<th><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,4);">IP Pool Ending Address</a></th>
<td>
<input type="text" maxlength="15" class="input_15_table" name="dhcp_end" value="<% nvram_get("dhcp_end"); %>" onKeyPress="return validator.isIPAddr(this,event)" autocorrect="off" autocapitalize="off">
</td>
</tr>

<tr>
<th><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,5);">Lease time</a></th>
<td>
<input type="text" maxlength="6" name="dhcp_lease" class="input_15_table" value="<% nvram_get("dhcp_lease"); %>" onKeyPress="return validator.isNumber(this,event)" autocorrect="off" autocapitalize="off">
</td>
</tr>

<tr>
<th><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,6);">Default Gateway</a></th>
<td>
<input type="text" maxlength="15" class="input_15_table" name="dhcp_gateway_x" value="<% nvram_get("dhcp_gateway_x"); %>" onKeyPress="return validator.isIPAddr(this,event)" autocorrect="off" autocapitalize="off">
</td>
</tr>

<tr>
<th>Sip Server</th>
<td>
<input type="text" maxlength="15" class="input_15_table" name="sip_server" value="<% nvram_get("sip_server"); %>" onKeyPress="return validator.isIPAddr(this,event)" autocorrect="off" autocapitalize="off">
</td>
</tr>

</table>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3"  class="FormTable" style="margin-top:8px">
	
<thead><tr><td colspan="2">DNS and WINS Server Setting</td></tr></thead>

<tr>
<th width="200"><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,7);">DNS Server 1</a></th>
<td>
<input type="text" maxlength="15" class="input_15_table" name="dhcp_dns1_x" value="<% nvram_get("dhcp_dns1_x"); %>" onKeyPress="return validator.isIPAddr(this,event)" autocorrect="off" autocapitalize="off">
<div id="yadns_hint" style="display:none;"></div>
</td>
</tr>

<tr>
<th width="200"><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,7);">DNS Server 2</a></th>
<td>
<input type="text" maxlength="15" class="input_15_table" name="dhcp_dns2_x" value="<% nvram_get("dhcp_dns2_x"); %>" onKeyPress="return validator.isIPAddr(this,event)">
</td>
</tr>

<tr>
<th>Advertise router's IP in addition to user-specified DNS</th>
<td>
<input type="radio" value="1" name="dhcpd_dns_router" class="content_input_fd" onclick="return change_common_radio(this, 'LANHostConfig', 'dhcpd_dns_router', '1')" <% nvram_match("dhcpd_dns_router", "1", "checked"); %>>Yes
<input type="radio" value="0" name="dhcpd_dns_router" class="content_input_fd" onclick="return change_common_radio(this, 'LANHostConfig', 'dhcpd_dns_router', '0')" <% nvram_match("dhcpd_dns_router", "0", "checked"); %>>No
</td>
</tr>

<tr>
<th><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,8);">WINS Server</a></th>
<td>
<input type="text" maxlength="15" class="input_15_table" name="dhcp_wins_x" value="<% nvram_get("dhcp_wins_x"); %>" onkeypress="return validator.isIPAddr(this,event)" autocorrect="off" autocapitalize="off"/>
</td>
</tr>

</table>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable" style="margin-top:8px;" >
<thead><tr><td colspan="3">Manual Assignment</td></tr></thead>

<tr>
<th><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,9);">Enable Manual Assignment</a></th>
<td colspan="2" style="text-align:left;">
<input type="radio" value="1" name="dhcp_static_x"  onclick="return change_common_radio(this, 'LANHostConfig', 'dhcp_static_x', '1')" <% nvram_match("dhcp_static_x", "1", "checked"); %> />Yes
<input type="radio" value="0" name="dhcp_static_x"  onclick="return change_common_radio(this, 'LANHostConfig', 'dhcp_static_x', '0')" <% nvram_match("dhcp_static_x", "0", "checked"); %> />No
</td>
</tr>
</table>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable_table" style="margin-top:8px;">
<thead><tr><td colspan="5" id="GWStatic">Manually Assigned IP around the DHCP list&nbsp;(Max Limit :&nbsp;64)</td></tr></thead>

<tr>
<th id="col0" style="cursor: pointer;" onclick="sortlist(0); showdhcp_staticlist();"><a class="hintstyle" href="javascript:void(0);" onclick="openHint(5,10);">Client Name (MAC Address)</a></th>
<th id="col1" style="cursor: pointer;" onclick="sortlist(1); showdhcp_staticlist();">IP Address</th>
<th id="col3" style="cursor: pointer;" onclick="sortlist(3); showdhcp_staticlist();">DNS Server (Optional)</th>
<th id="col2" style="cursor: pointer;" onclick="sortlist(2); showdhcp_staticlist();">Hostname (Optional)</th>
<th>Edit</th>
</tr>

<tr>
<td width="32%">
<input type="text" class="input_20_table" maxlength="17" name="dhcp_staticmac_x_0" style="margin-left:-12px;width:170px;" onKeyPress="return validator.isHWAddr(this,event)" onclick="hideClients_Block();" autocorrect="off" autocapitalize="off" placeholder="ex: <% nvram_get("lan_hwaddr"); %>">
<img id="pull_arrow" height="14px;" src="/images/arrow-down.gif" style="position:absolute;*margin-left:-3px;*margin-top:1px;" onclick="pullLANIPList(this);" title="Select the MAC address of the DHCP client.">
<div id="ClientList_Block_PC" class="clientlist_dropdown" style="margin-left:9px;"></div>
</td>
<td width="19%">
<input type="text" class="input_15_table" maxlength="15" name="dhcp_staticip_x_0" onkeypress="return validator.isIPAddr(this,event)" autocorrect="off" autocapitalize="off">
</td>
<td width="19%">
<input type="text" class="input_15_table" maxlength="15" name="dhcp_dnsip_x_0" onkeypress="return validator.isIPAddr(this,event)" autocorrect="off" autocapitalize="off">
</td>
<td width="23%">
<input type="text" class="input_15_table" maxlenght="30" onkeypress="return validator.isString(this, event);" name="dhcp_staticname_x_0" autocorrect="off" autocapitalize="off">
</td>
<td width="7%">
<div>
<input type="button" class="add_btn" onclick="addRow_Group(64);" value="">
</div>
</td>
</tr>

</table>

<div id="dhcp_staticlist_Block"></div>

<div class="apply_gen"><input type="button" name="button" class="button_gen" onclick="applyRule();" value="Apply"/></div>

</td>
</tr>
</tbody>
</table>
</td>
</tr>
</table>
</td>
</tr>
</table>
</form>
<form method="post" name="formScriptActions" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="productid" value="<% nvram_get("productid"); %>">
<input type="hidden" name="current_page" value="">
<input type="hidden" name="next_page" value="">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_script" value="">
<input type="hidden" name="action_wait" value="">
</form>
<div id="footer"></div>
</body>
</html>
