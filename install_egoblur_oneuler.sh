#!/bin/bash

# Set the base directory
BASE_DIR="/cluster/project/hilliges/ayavuz"

# Purge all modules to start with a clean environment
module purge

# Load necessary modules
module load stack/2024-06 gcc/12.2.0 cmake/3.27.7 \
  fmt/9.1.0-ytzonih libjpeg-turbo/3.0.0 \
  libpng/1.6.39-fz4tvmr lz4/1.9.4-u5ij5nz \
  zstd/1.5.5-tbljaiw xxhash/0.8.1-ipjvat6 \
  boost/1.83.0 python/3.11.6 \
  cuda/12.1.1 cudnn/8.9.7.29-12 \
  libtorch/2.1.0 zlib/1.3-mktm5vz \
  ninja/1.11.1-y43vkfa

# Set the TORCH_CUDA_ARCH_LIST environment variable
export TORCH_CUDA_ARCH_LIST="7.0;7.5;8.0;8.6;8.9"

# Set environment variables based on your system's environment
export TORCH_DIR=$LIBTORCH_EULER_ROOT/share/cmake/Torch
export CUDA_HOME=$CUDA_EULER_ROOT
export CUDNN_ROOT=$CUDNN_EULER_ROOT
export PYTHON_ROOT=$PYTHON_EULER_ROOT
export BOOST_ROOT=$BOOST_EULER_ROOT
export FMT_ROOT=$FMT_EULER_ROOT
export LIBJPEG_TURBO_ROOT=$LIBJPEG_TURBO_EULER_ROOT
export LIBPNG_ROOT=$LIBPNG_EULER_ROOT
export LZ4_ROOT=$LZ4_EULER_ROOT
export ZSTD_ROOT=$ZSTD_EULER_ROOT
export XXHASH_ROOT=$XXHASH_EULER_ROOT
export ZLIB_ROOT=$ZLIB_EULER_ROOT

# Update environment variables
export LD_LIBRARY_PATH=$LIBTORCH_EULER_ROOT/lib:$CUDA_HOME/lib64:$CUDNN_ROOT/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$FMT_ROOT/lib:$LIBJPEG_TURBO_ROOT/lib:$LIBPNG_ROOT/lib:$LZ4_ROOT/lib:$ZSTD_ROOT/lib:$XXHASH_ROOT/lib:$ZLIB_ROOT/lib

export PATH=$CUDA_HOME/bin:$PATH

export CPATH=$LIBTORCH_EULER_ROOT/include:$CUDA_HOME/include:$CUDNN_ROOT/include:$CPATH
export CPATH=$CPATH:$FMT_ROOT/include:$LIBJPEG_TURBO_ROOT/include:$LIBPNG_ROOT/include:$LZ4_ROOT/include:$ZSTD_ROOT/include:$XXHASH_ROOT/include:$ZLIB_ROOT/include

export CMAKE_PREFIX_PATH=$LIBTORCH_EULER_ROOT:$CUDA_HOME:$CUDNN_ROOT:$PYTHON_ROOT:$BOOST_ROOT:$FMT_ROOT:$LIBJPEG_TURBO_ROOT:$LIBPNG_ROOT:$LZ4_ROOT:$ZSTD_ROOT:$XXHASH_ROOT:$ZLIB_ROOT

# Create the repos directory if it doesn't exist
mkdir -p $BASE_DIR/repos
cd $BASE_DIR/repos

#######################################
# Step 1: Build TorchVision
#######################################

echo "Building TorchVision..."

# Clone TorchVision repository if not already cloned
if [ ! -d "vision" ]; then
  git clone --branch v0.16.0 https://github.com/pytorch/vision.git
else
  cd vision
  git pull
  cd ..
fi

# Clean previous build of TorchVision
rm -rf vision/build
mkdir -p vision/build
cd vision/build

# Configure TorchVision build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DTORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST \
  -DWITH_CUDA=on \
  -DTorch_DIR=$TORCH_DIR \
  -DCMAKE_INSTALL_PREFIX=$BASE_DIR/local && \
make -j$(nproc) && \
make install

export PATH=$BASE_DIR/local/bin:$PATH
export LD_LIBRARY_PATH=$BASE_DIR/local/lib:$LD_LIBRARY_PATH
export CMAKE_PREFIX_PATH=$BASE_DIR/local:$CMAKE_PREFIX_PATH


# Set TorchVision_DIR
export TorchVision_DIR=$BASE_DIR/repos/vision/cmake

# Update CMAKE_PREFIX_PATH to include TorchVision
export CMAKE_PREFIX_PATH=$TorchVision_DIR:$CMAKE_PREFIX_PATH

# Return to repos directory
cd $BASE_DIR/repos

#######################################
# Step 2: Build OpenCV
#######################################

echo "Building OpenCV..."

# Check if OpenCV is already installed
if [ ! -d "$BASE_DIR/local/lib/cmake/opencv4" ]; then
  # Clone OpenCV repository if not already cloned
  if [ ! -d "opencv" ]; then
    git clone https://github.com/opencv/opencv.git
    cd opencv
    git checkout 4.8.0
    cd ..
  else
    cd opencv
    git pull
    cd ..
  fi

  # Clean previous build of OpenCV
  rm -rf opencv/build
  mkdir -p opencv/build
  cd opencv/build

  # Configure OpenCV build
  cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$BASE_DIR/local \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_opencv_python=OFF \
    -DBUILD_opencv_java=OFF \
    -DWITH_CUDA=OFF \
    -DWITH_OPENCL=OFF \
    -DWITH_IPP=OFF \
    -DWITH_TBB=OFF \
    -DWITH_EIGEN=OFF \
    -DWITH_FFMPEG=OFF \
    -DBUILD_SHARED_LIBS=ON

  # Build and install OpenCV
  make -j$(nproc)
  make install

  # Return to repos directory
  cd $BASE_DIR/repos
else
  echo "OpenCV is already installed."
fi

# Set OpenCV_DIR
export OpenCV_DIR=$BASE_DIR/local/lib/cmake/opencv4

# Update CMAKE_PREFIX_PATH to include OpenCV
export CMAKE_PREFIX_PATH=$OpenCV_DIR:$CMAKE_PREFIX_PATH

#######################################
# Step 3: Clone and Build EgoBlur VRS Mutation Tool
#######################################

# Clean previous builds of EgoBlur
rm -rf $BASE_DIR/repos/EgoBlur/tools/vrs_mutation/build

# Clone EgoBlur repository if not already cloned
if [ ! -d "EgoBlur" ]; then
  git clone https://github.com/facebookresearch/EgoBlur.git
else
  cd EgoBlur
  git pull
  cd ..
fi

cd EgoBlur/tools/vrs_mutation

# Clean previous build of EgoBlur VRS mutation tool
rm -rf build
mkdir -p build && cd build

# Build the EgoBlur VRS mutation tool
cmake .. \
  -DTorch_DIR=$TORCH_DIR \
  -DTorchVision_DIR=$TorchVision_DIR

make -j ego_blur_vrs_mutation

echo "EgoBlur VRS mutation tool built successfully at $BASE_DIR."
