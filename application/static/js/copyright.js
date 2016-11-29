'use strict';

(function () {
  var copyrightElement = void 0,
      year = void 0;
  copyrightElement = document.getElementById('copyright');
  year = new Date().getFullYear();
  copyrightElement.innerHTML = '&copy; ' + year + '. All Rights Reserved.';
})();