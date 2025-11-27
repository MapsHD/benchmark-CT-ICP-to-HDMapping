ARG ROS_DISTRO=noetic
FROM ros:${ROS_DISTRO}-ros-base
ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-lc"]

RUN apt-get update && apt-get install -y python3-colcon-common-extensions ros-${ROS_DISTRO}-pcl-ros git nlohmann-json3-dev libpcl-dev python3-pip
RUN pip3 install rosbags
RUN mkdir -p /test_ws/src
COPY src/ /test_ws/src
# Skip ct_icp from colcon build - it's not a ROS package and requires superbuild
RUN touch /test_ws/src/ct_icp/COLCON_IGNORE
RUN if [ ! -f /test_ws/src/livox_ros_driver/package.xml ]; then rm -rf /test_ws/src/livox_ros_driver && git clone https://github.com/Livox-SDK/livox_ros_driver.git /test_ws/src/livox_ros_driver; fi
RUN cd /test_ws && source /opt/ros/${ROS_DISTRO}/setup.bash && rosdep update && rosdep install --from-paths src --ignore-src -r -y || true && source /opt/ros/${ROS_DISTRO}/setup.bash && colcon build
