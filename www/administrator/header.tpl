<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"> 
<html lang="en" dir="ltr" xmlns="http://www.w3.org/1999/xhtml"> 
    <head> 
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" /> 
        <meta http-equiv="Content-Style-Type" content="text/css" /> 
		<title><tmpl_var name="service_name"> panel (<tmpl_var name="server_name">)</title>

        <style type="text/css">
        
* {
    font-family: arial, sans-serif
}

body {
    background-color: #F8F8F8;
    padding: 0;
    margin: 0
}

a {
    text-decoration: none;
    color: blue;
    padding: 0;
    margin: 0;
}

a:hover { color: green; }

div#container {
    width: 950px;
    min-width: 900px; /* for full-width */
    margin: auto;
    margin-top: 20px;
    margin-bottom: 20px;
    padding: 0;
    border: 2px solid #ccc;
    background-color: #fff;
}

#content {
    min-height: 500px;
    padding: 10px;
    font-size: .9em;
}

#header {
    background-color: #eee;
    color: #fff;
    padding: 10px 10px 0px 10px;
    height: 60px;
    border-bottom: 1px solid #ccc;
}

#h-left {
    float: left;
    width: 50%;
    height: 50px;
}

#h-right {
    float: right;
    text-align: right;
    height: 50px;
    width: 50%;
    color: #111;
    font-size: 13px;
    line-height: 18px;
}

#footer {
    background-color: #eee;
    padding: 10px;
    font-size: small;
    margin: auto;
    font-family: arial;
    border-top: 1px solid #ccc
}

#footerlogo, h1, h2, h3, h4 {
    text-shadow: darkgray 1px 1px 4px
}

code {
    background-color: #F8F8F8;
    border: 1px solid #ccc;
    display: inline-block;
    padding: 10px;
}

#admin-logo {
    max-height: 50px;
}

        </style>
    </head>

    <body>
        <div id="container">
            <div id="header">
                <div id="h-left">
                    <a href="/panel">
                        <img id="admin-logo" src="<tmpl_var name=service_logo_url>" alt="<tmpl_var name=service_name>"  />
                    </a>
                </div>
                <div id="h-right">
                    <span style="font-weight: bold"><tmpl_var name="server_name"></span><br />
                    <tmpl_var name="service_name"> client server<br />
                    <tmpl_var name="server_uptime">
                </div>
            </div>
            <div id="content">

