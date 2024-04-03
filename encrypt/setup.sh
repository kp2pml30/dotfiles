dd if=/dev/zero of=./encrypted.vhdx bs=1M count=1024
sudo losetup /dev/loop0 ./encrypted.vhdx
sudo cryptsetup -q luksFormat -y /dev/loop0
sudo cryptsetup open /dev/loop0 loop0
sudo mkfs.ext4 /dev/mapper/loop0
sudo mkdir /encrypt
sudo chmod 777 /encrypt
sudo mount /dev/mapper/loop0 /encrypt
