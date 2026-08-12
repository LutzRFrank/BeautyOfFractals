const languagePreferenceKey = "beauty-of-fractals-language";

const getSavedLanguage = () => {
  try {
    return window.localStorage.getItem(languagePreferenceKey);
  } catch {
    return null;
  }
};

const saveLanguage = (language) => {
  try {
    window.localStorage.setItem(languagePreferenceKey, language);
  } catch {
    // The language switch still works when storage is unavailable.
  }
};

document.querySelectorAll(".language-switch a[lang]").forEach((link) => {
  link.addEventListener("click", () => saveLanguage(link.lang));
});

const currentFile = window.location.pathname.split("/").pop();
const isDefaultEntry = currentFile === "" || currentFile === "index.html";

if (isDefaultEntry) {
  const savedLanguage = getSavedLanguage();
  const systemLanguage = (navigator.language || "en").toLowerCase();
  const preferredLanguage = savedLanguage || (systemLanguage.startsWith("de") ? "de" : "en");

  if (preferredLanguage === "en") {
    window.location.replace(new URL("index-en.html", window.location.href));
  }
}

const slides = [...document.querySelectorAll(".fractal")];
let currentSlide = 0;

if (slides.length > 1 && !window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
  window.setInterval(() => {
    slides[currentSlide].classList.remove("is-active");
    currentSlide = (currentSlide + 1) % slides.length;
    slides[currentSlide].classList.add("is-active");
  }, 5200);
}

const lightbox = document.querySelector(".lightbox");
const lightboxImage = lightbox?.querySelector("img");
const closeButton = lightbox?.querySelector(".lightbox-close");

document.querySelectorAll(".gallery-item").forEach((item) => {
  item.addEventListener("click", () => {
    if (!lightbox || !lightboxImage) return;
    lightboxImage.src = item.dataset.image;
    lightboxImage.alt = item.querySelector("img")?.alt ?? "Fraktal";
    lightbox.showModal();
  });
});

closeButton?.addEventListener("click", () => lightbox.close());
lightbox?.addEventListener("click", (event) => {
  if (event.target === lightbox) lightbox.close();
});
