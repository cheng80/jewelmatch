/**
 * Jewel Match 웹 페이지 — 한국어/영어 언어 전환 스크립트
 * localStorage에 선택 언어를 저장하여 페이지 이동 시에도 유지
 */
(function () {
  const STORAGE_KEY = 'jewelmatch-lang';

  function getDomainText() {
    if (window.location && window.location.hostname) {
      return window.location.hostname;
    }
    return 'cheng80.myqnapcloud.com';
  }

  function applyDomainText() {
    var domain = getDomainText();
    document.querySelectorAll('[data-domain]').forEach(function (el) {
      el.textContent = domain;
    });
  }

  function getLang() {
    return localStorage.getItem(STORAGE_KEY) || 'ko';
  }

  function setLang(lang) {
    localStorage.setItem(STORAGE_KEY, lang);
    applyLang(lang);
  }

  function applyLang(lang) {
    document.documentElement.lang = lang;

    document.querySelectorAll('[data-ko]').forEach(function (el) {
      var text = lang === 'ko' ? el.getAttribute('data-ko') : el.getAttribute('data-en');
      if (text !== null) {
        if (el.tagName === 'A' && el.getAttribute('href') && el.getAttribute('href').startsWith('mailto:')) {
          return;
        }
        el.innerHTML = text;
      }
    });

    document.querySelectorAll('.lang-btn').forEach(function (btn) {
      btn.classList.toggle('active', btn.getAttribute('data-lang') === lang);
    });

    document.querySelectorAll('[data-ko-display]').forEach(function (el) {
      el.style.display = lang === 'ko' ? '' : 'none';
    });
    document.querySelectorAll('[data-en-display]').forEach(function (el) {
      el.style.display = lang === 'en' ? '' : 'none';
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    applyDomainText();
    var lang = getLang();
    applyLang(lang);

    document.querySelectorAll('.lang-btn').forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        setLang(btn.getAttribute('data-lang'));
      });
    });
  });
})();
