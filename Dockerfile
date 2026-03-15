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
    catkin_make --only-pkg-with-deps slam_roscore -DSUPERBUILD_INSTALL_DIR=/ros_ws/src/ct_icp/install

RUN source /opt/ros/noetic/setup.bash && \
    catkin_make --only-pkg-with-deps ct_icp_odometry -DSUPERBUILD_INSTALL_DIR=/ros_ws/src/ct_icp/install && \
    catkin_make --pkg ct_icp_odometry -DSUPERBUILD_INSTALL_DIR=/ros_ws/src/ct_icp/install && \
    catkin_make --only-pkg-with-deps ct-icp-to-hdmapping
     
RUN sed -i 's|<arg name="topic" value="/rslidar_points"/>|<arg name="topic" value="/livox/pointcloud"/>|g' \
    /ros_ws/src/ct_icp/ros/catkin_ws/ct_icp_odometry/launch/urban_loco/urban_loco_CAL.launch

ARG UID=1000
ARG GID=1000
RUN groupadd -g $GID ros && \
    useradd -m -u $UID -g $GID -s /bin/bash ros
    
WORKDIR /ros_ws

RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc && \
    echo "source /ros_ws/devel/setup.bash" >> ~/.bashrc

CMD ["bash"]