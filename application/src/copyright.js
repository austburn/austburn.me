(() => {
  let copyrightElement, year;
  copyrightElement = document.getElementById('copyright');
  year = new Date().getFullYear();
  copyrightElement.innerHTML = `&copy; ${year}. All Rights Reserved.`;
})();
