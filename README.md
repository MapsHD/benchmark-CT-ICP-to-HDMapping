# CT-ICP converter

## Example Dataset: 

Download the dataset from [Bunker DVI Dataset](https://charleshamesse.github.io/bunker-dvi-dataset/)  

## Dependecies
```shell
sudo apt install nlohmann-json3-dev
sudo apt install libssl-dev
```
## For build
```shell
wget https://cmake.org/files/v3.20/cmake-3.20.5.tar.gz
tar -zxvf cmake-3.20.5.tar.gz
cd cmake-3.20.5
./bootstrap
make
sudo make install
```

## Intended use 

This small toolset allows to integrate SLAM solution provided by [ct-icp](https://github.com/jedeschaud/ct_icp/) with [HDMapping](https://github.com/MapsHD/HDMapping).
This repository contains ROS 1 workspace that :
  - submodule to tested revision of CT ICP
  - a converter that listens to topics advertised from odometry node and save data in format compatible with HDMapping.

## Building

```shell
mkdir -p /test_ws/src
cd /test_ws/src
git clone https://github.com/marcinmatecki/ct-icp-to-hdmapping.git --recursive

cd ct-icp-to-hdmapping/src/ct_icp
mkdir .cmake-build-superbuild
cd .cmake-build-superbuild
cmake ../superbuild
cmake --build . --config Release

cd ..
mkdir cmake-build-release 
cd  cmake-build-release
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --target install --config Release --parallel 12

cd ..
cd ros/roscore
mkdir cmake-build-release && cd  cmake-build-release
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --target install --config Release --parallel 12

cd /test_ws/
catkin_make -DSUPERBUILD_INSTALL_DIR=<path-to-superbuild-install-dir>
```

## Usage - data SLAM:

Prepare recorded bag with estimated odometry:

In first terminal record bag:
```shell
rosbag record /ct_icp/world_points /ct_icp/pose/odom
```

and start odometry:
```shell 
cd /test_ws/
source ./devel/setup.sh # adjust to used shell
roslaunch ct_icp_odometry urban_loco_CAL.launch rosbag:=<path_to_rosbag>
```

## Usage - conversion:

```shell
cd /test_ws/ct_icp/
source ./devel/setup.sh # adjust to used shell
rosrun ct-icp-to-hdmapping listener <recorded_bag> <output_dir>
```

## Record the bag file:

```shell
rosbag record /ct_icp/world_points /ct_icp/pose/odom -o {your_directory_for_the_recorded_bag}
```

## CT-ICP Launch:

```shell
cd /test_ws/
source ./devel/setup.sh # adjust to used shell
roslaunch ct_icp_odometry urban_loco_CAL.launch rosbag:=<path_to_rosbag>
```

## During the record (if you want to stop recording earlier) / after finishing the bag:

```shell
In the terminal where the ros record is, interrupt the recording by CTRL+C
Do it also in ros launch terminal by CTRL+C.
```

## Usage - Conversion (ROS bag to HDMapping, after recording stops):

```shell
cd /test_ws/
source ./devel/setup.sh # adjust to used shell
rosrun ct-icp-to-hdmapping listener <recorded_bag> <output_dir>
```
