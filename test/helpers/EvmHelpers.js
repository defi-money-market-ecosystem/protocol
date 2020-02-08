const {time} = require('@openzeppelin/test-helpers');

const advanceTimeBySeconds = (durationSeconds) => {
  return time.increase(durationSeconds);
};

module.exports = {
  advanceTimeBySeconds
};