FROM ubuntu:20.04

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 lsb-release software-properties-common \
    build-essential git cmake \
    python3-pip \
    libceres-dev \
    libpcl-dev \
    nlohmann-json3-dev \
    tmux \
    libusb-1.0-0-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros/ubuntu $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/ros1.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-noetic-desktop-full \
    python3-rosdep \
    python3-catkin-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN wget https://cmake.org/files/v3.20/cmake-3.20.5.tar.gz && \
    tar -zxvf cmake-3.20.5.tar.gz && \
    cd cmake-3.20.5 && \
    ./bootstrap && \
    make -j$(nproc) && \
    make install

ENV PATH=/usr/local/bin:$PATH

RUN git clone https://github.com/Livox-SDK/Livox-SDK.git && \
    cd Livox-SDK && \
    rm -rf build && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install

WORKDIR /ros_ws

COPY ./src ./src

WORKDIR /ros_ws/src/ct_icp

RUN mkdir .cmake-build-superbuild && \
    cd .cmake-build-superbuild && \
    cmake ../superbuild && \
    cmake --build . --config Release

WORKDIR /ros_ws/src/ct_icp 

RUN mkdir -p  cmake-build-release  && cd cmake-build-release && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --target install --parallel $(nproc)

WORKDIR /ros_ws/src/ct_icp/ros/roscore

RUN source /opt/ros/noetic/setup.bash && \
    mkdir cmake-build-release && cd  cmake-build-release && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --target install --config Release --parallel 12

WORKDIR /ros_ws

RUN rm -rf /ros_ws/src/ct_icp/.cmake-build-superbuild && \
    mkdir -p /ros_ws/src/ct_icp/.cmake-build-superbuild && \
    cd /ros_ws/src/ct_icp/.cmake-build-superbuild && \
    cmake .. -DCMAKE_CXX_STANDARD=14 && \
    make  && make install

WORKDIR /opt

RUN git clone https://github.com/google/googletest.git && \
cd googletest && \
mkdir build && cd build && \
cmake .. && \
make -j$(nproc) && \
make install

WORKDIR /ros_ws
RUN source /opt/ros/noetic/setup.bash && \
    catkin_make \
     -DSUPERBUILD_INSTALL_DIR=/ros_ws/src/ct_icp/install
     
# california.yaml (vehicle-speed UrbanLoco tuning: CONSTANT_VELOCITY init,
# large sample/frame voxels) produced trajectories that "converged successfully"
# every frame per the logs but drifted badly on Oxford Spires' walking-pace
# data. nhcd_config.yaml (Newer College Dataset -- an Oxford handheld/backpack
# LiDAR dataset, same motion profile as Oxford Spires) uses CONTINUOUS motion
# compensation + INIT_NONE + finer voxels, a much closer match.
RUN sed -i 's|<arg name="topic" value="/os1_cloud_node/points"/>|<arg name="topic" value="/hesai/pandar"/>|g' \
    /ros_ws/src/ct_icp/ros/catkin_ws/ct_icp_odometry/launch/nhcd/lidar_odometry_nhcd_os64.launch

# nhcd_config.yaml assumes NHCD's Ouster reports per-point time as nanoseconds
# relative to scan start ("unit: NANO_SECONDS"), so expected_dt is scaled to
# ~1e8. Hesai's "timestamp" field is float64 SECONDS (absolute epoch), so dt
# comes out ~0.1 -- against a ~1e8 threshold that's r_dt~1e-9, and every frame
# gets rejected as "Inconsistent Timestamp" / skipped. Override just the unit.
RUN sed -i 's|unit: NANO_SECONDS|unit: SECONDS|' \
    /ros_ws/src/ct_icp/ros/catkin_ws/ct_icp_odometry/params/ct_icp/nhcd/nhcd_config.yaml

# Temporary diagnostics: the node logs "Found Inconsistent Timestamp"/"Skipping
# the frame" only when debug_print is on, needed to root-cause bad trajectories
# on the Oxford Spires (walking-pace) dataset vs. the vehicle-tuned california.yaml.
RUN sed -i 's|<arg name="debug_print" default="false"|<arg name="debug_print" default="true"|' \
    /ros_ws/src/ct_icp/ros/catkin_ws/ct_icp_odometry/launch/ct_icp_slam.launch

ARG UID=1000
ARG GID=1000
RUN groupadd -g $GID ros && \
    useradd -m -u $UID -g $GID -s /bin/bash ros
    
WORKDIR /ros_ws

RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc && \
    echo "source /ros_ws/devel/setup.bash" >> ~/.bashrc

CMD ["bash"]
