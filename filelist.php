<?php
$output = shell_exec("ls -hl /home/encoding/source/2 | grep -e \.mkv$ -e \.mp4$ -e \.avi$ -e \.mov$ | awk '{print $5,$9}'");

echo "<pre>$output</pre>";
