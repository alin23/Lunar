#include "Adafruit_TSL2591.h"
#include "esphome.h"

class Tsl2591 : public PollingComponent, public Sensor {
public:
    Tsl2591()
        : PollingComponent(1000)
    {
    }
    Adafruit_TSL2591 tsl = Adafruit_TSL2591(2591);

    void setup() override
    {
        if (!tsl.begin()) {
            ESP_LOGD("ERROR", "Could not find a TSL2591 Sensor. Did you configure I2C?");
        }
        tsl.setGain(TSL2591_GAIN_MED);
        tsl.setTiming(TSL2591_INTEGRATIONTIME_600MS);
    }
    void update() override
    {
        uint32_t full = tsl.getFullLuminosity();
        uint16_t ch0 = full & 0xffff;
        uint16_t ch1 = full >> 16;
        float lux = tsl.calculateLux(ch0, ch1);

        publish_state(lux);
    }
};