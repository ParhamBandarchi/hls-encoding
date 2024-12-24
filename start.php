<?php

/*ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);*/

$folder = '2';

$getencoder = trim($_GET['encoder'] ?? '');

$encoderlist = ['batch-2160p.sh', 'batch-1080p.sh', 'batch-dual-1080p.sh', 'batch-720p.sh'];

if (in_array($getencoder, $encoderlist)) {
	$encoder = $getencoder;
} else {
	$encoder = 'batch-1080p.sh';
}

$free = trim(shell_exec('df --output=avail -B 1 "$PWD" | tail -n 1'));

if ($free < 53687091200) {
 echo 'not enough free space';
 exit;
}

$status_file = dirname(__FILE__) . '/' . 'status.txt';

$run = false;

if (file_exists($status_file)) {

 $status = file_get_contents($status_file);
 $status = trim($status);
 
 if ($status == 'done') {
  $run = true;
 }

} else {
 $run = true;
}

//var_dump($run);

if ($run == true) {
 shell_exec('cd /home/encoding/source/' . $folder . '/ && ./' . $encoder);
 
 echo 'start';
 
} else {
 
 echo $status;
 
}

exit;
