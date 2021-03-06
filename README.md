# Teknoir Darknet App C++
A small footprint c++ darknet app.
A base for building c++ apps on the teknoir platform.

## Build
Nvidia has made it virtually impossble to create a pure cloud based pipeline for the Jetson Nano.
The base image has to be built on a real Jetson Nano with matching Jetpack version.
### Build on Jentson Nano
Clone this repo and run:
```bash
./build_on_devboard.sh
```

To add yolov3, yolov3-tiny and yolov4 to the docker images:
```bash
gcloud builds submit . --config=cloudbuild.yaml --timeout=3600 --substitutions=SHORT_SHA="$(date +v%Y%m%d)-$(git describe --tags --always --dirty)-$(git diff | shasum -a256 | cut -c -6)"
```

## Build locally
```bash
cd app
mkdir build
cd build
cmake ..
make
make install
```

## Run interactively on device
```bash
sudo kubectl run darknet -ti --rm --image tekn0ir/darknet:arm64v8 --overrides='{"spec":{"imagePullSecrets":[{"name":"gcr-json-key"}],"containers":[{"name":"darknet","image":"tekn0ir/darknet:arm64v8","command":["/bin/bash"],"tty":true,"stdin":true,"imagePullPolicy":"Always","securityContext":{"privileged":true},"env":[{"name":"MQTT_SERVICE_HOST","value":"mqtt.kube-system"},{"name":"MQTT_SERVICE_PORT","value":"1883"},{"name":"MQTT_IN_0","value":"camera/images"},{"name":"MQTT_OUT_0","value":"toe/events"},{"name":"NAMES_FILE","value":"/darknet/coco.names"},{"name":"CFG_FILE","value":"/darknet/yolov3.cfg"},{"name":"WEIGHTS_FILE","value":"/darknet/yolov3.weights"}]}]}}'

teknoir_app
```

## Run locally
```bash
docker run -it --rm -p 1883:1883 -p 9001:9001 --name mqtt-broker eclipse-mosquitto
# and in another terminal window run:
docker run -it --rm -e MQTT_SERVICE_HOST=<YOUR IP> tekn0ir/darknet:arm64v8
```
To stop the example press `ctrl-c`.


## Legacy build and publish docker images
```bash
docker build -t tekn0ir/darknet:amd64 -f amd64.Dockerfile .
docker push tekn0ir/darknet:amd64
```
```bash
docker build -t tekn0ir/darknet_base:arm32v7 -f arm32v7.base.Dockerfile .
docker push tekn0ir/darknet_base:arm32v7
docker build -t tekn0ir/darknet:arm32v7 -f arm32v7.Dockerfile .
docker push tekn0ir/darknet:arm32v7
```



struct bbox_t {
    unsigned int x, y, w, h;    // (x,y) - top-left corner, (w, h) - width & height of bounded box
    float prob;                    // confidence - probability that the object was found correctly
    unsigned int obj_id;        // class of object - from range [0, classes-1]
    unsigned int track_id;        // tracking id for video (0 - untracked, 1 - inf - tracked object)
    unsigned int frames_counter;// counter of frames on which the object was detected
};

class Detector {
public:
        Detector(std::string cfg_filename, std::string weight_filename, int gpu_id = 0);
        ~Detector();

        std::vector<bbox_t> detect(std::string image_filename, float thresh = 0.2, bool use_mean = false);
        std::vector<bbox_t> detect(image_t img, float thresh = 0.2, bool use_mean = false);
        static image_t load_image(std::string image_filename);
        static void free_image(image_t m);

#ifdef OPENCV
        std::vector<bbox_t> detect(cv::Mat mat, float thresh = 0.2, bool use_mean = false);
	std::shared_ptr<image_t> mat_to_image_resize(cv::Mat mat) const;
#endif
};