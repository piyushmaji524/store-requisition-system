/**
 * ============================================================
 * UNIVERSAL APP MODAL & DIALOG SYSTEM
 * Modern, animated, responsive modal dialogs.
 * Permanently removes browser native popups and domain banners.
 * ============================================================
 */

const AppModal = (function () {
  let overlayEl = null;

  function ensureOverlay() {
    if (!overlayEl) {
      overlayEl = document.createElement('div');
      overlayEl.className = 'app-modal-overlay';
      overlayEl.innerHTML = '<div class="app-modal-card"></div>';
      document.body.appendChild(overlayEl);

      overlayEl.addEventListener('click', (e) => {
        if (e.target === overlayEl && overlayEl._allowBackdropDismiss) {
          closeModal(null);
        }
      });
    }
    return overlayEl;
  }

  function getCard() {
    return ensureOverlay().querySelector('.app-modal-card');
  }

  function openModal(htmlContent, onSetup, allowBackdrop = false) {
    const overlay = ensureOverlay();
    const card = getCard();
    overlay._allowBackdropDismiss = allowBackdrop;
    card.innerHTML = htmlContent;

    if (typeof onSetup === 'function') {
      onSetup(card);
    }

    // Force reflow and show
    requestAnimationFrame(() => {
      overlay.classList.add('app-modal-active');
    });
  }

  function closeModal(resolveVal) {
    if (!overlayEl) return;
    overlayEl.classList.remove('app-modal-active');
    if (typeof overlayEl._resolver === 'function') {
      overlayEl._resolver(resolveVal);
      overlayEl._resolver = null;
    }
  }

  return {
    /**
     * Modern Alert Dialog
     */
    alert: function (message, title = 'Notification', type = 'info') {
      return new Promise((resolve) => {
        let iconHtml = 'ℹ️';
        let iconClass = 'app-modal-icon-blue';

        if (type === 'success') {
          iconHtml = '✓';
          iconClass = 'app-modal-icon-green';
        } else if (type === 'warning') {
          iconHtml = '⚠️';
          iconClass = 'app-modal-icon-amber';
        } else if (type === 'error' || type === 'danger') {
          iconHtml = '✕';
          iconClass = 'app-modal-icon-red';
        }

        const html = `
          <div class="app-modal-header">
            <div class="app-modal-icon-wrap ${iconClass}">${iconHtml}</div>
            <div class="app-modal-title-group">
              <h3 class="app-modal-title">${title}</h3>
              <p class="app-modal-subtitle">${message}</p>
            </div>
          </div>
          <div class="app-modal-footer">
            <button type="button" class="app-modal-btn app-modal-btn-primary" id="app-modal-ok-btn">OK</button>
          </div>
        `;

        ensureOverlay()._resolver = resolve;
        openModal(html, (card) => {
          const btn = card.querySelector('#app-modal-ok-btn');
          btn.focus();
          btn.onclick = () => closeModal(true);
        }, true);
      });
    },

    /**
     * Modern Confirmation Dialog
     */
    confirm: function (message, options = {}) {
      return new Promise((resolve) => {
        const title = options.title || 'Please Confirm';
        const confirmText = options.confirmText || 'Confirm';
        const cancelText = options.cancelText || 'Cancel';
        const type = options.type || 'primary'; // primary, danger, green, orange
        const subtitle = options.subtitle || message;

        let iconHtml = '❓';
        let iconClass = 'app-modal-icon-blue';
        let btnClass = 'app-modal-btn-primary';

        if (type === 'danger') {
          iconHtml = '🗑️';
          iconClass = 'app-modal-icon-red';
          btnClass = 'app-modal-btn-danger';
        } else if (type === 'green') {
          iconHtml = '✓';
          iconClass = 'app-modal-icon-green';
          btnClass = 'app-modal-btn-green';
        } else if (type === 'orange') {
          iconHtml = '⚡';
          iconClass = 'app-modal-icon-orange';
          btnClass = 'app-modal-btn-orange';
        }

        const html = `
          <div class="app-modal-header">
            <div class="app-modal-icon-wrap ${iconClass}">${iconHtml}</div>
            <div class="app-modal-title-group">
              <h3 class="app-modal-title">${title}</h3>
              <p class="app-modal-subtitle">${subtitle}</p>
            </div>
          </div>
          <div class="app-modal-footer">
            <button type="button" class="app-modal-btn app-modal-btn-cancel" id="app-modal-cancel-btn">${cancelText}</button>
            <button type="button" class="app-modal-btn ${btnClass}" id="app-modal-confirm-btn">${confirmText}</button>
          </div>
        `;

        ensureOverlay()._resolver = resolve;
        openModal(html, (card) => {
          card.querySelector('#app-modal-cancel-btn').onclick = () => closeModal(false);
          const confirmBtn = card.querySelector('#app-modal-confirm-btn');
          confirmBtn.focus();
          confirmBtn.onclick = () => closeModal(true);
        });
      });
    },

    /**
     * Modern Prompt Dialog
     */
    prompt: function (message, defaultValue = '', options = {}) {
      return new Promise((resolve) => {
        const title = options.title || 'Input Required';
        const placeholder = options.placeholder || 'Enter value...';
        const inputType = options.inputType || 'text';
        const confirmText = options.confirmText || 'OK';

        const html = `
          <div class="app-modal-header">
            <div class="app-modal-icon-wrap app-modal-icon-blue">✏️</div>
            <div class="app-modal-title-group">
              <h3 class="app-modal-title">${title}</h3>
              <p class="app-modal-subtitle">${message}</p>
            </div>
          </div>
          <div class="app-modal-body">
            <input type="${inputType}" class="app-modal-input" id="app-modal-prompt-input" value="${defaultValue}" placeholder="${placeholder}">
          </div>
          <div class="app-modal-footer">
            <button type="button" class="app-modal-btn app-modal-btn-cancel" id="app-modal-cancel-btn">Cancel</button>
            <button type="button" class="app-modal-btn app-modal-btn-primary" id="app-modal-ok-btn">${confirmText}</button>
          </div>
        `;

        ensureOverlay()._resolver = resolve;
        openModal(html, (card) => {
          const input = card.querySelector('#app-modal-prompt-input');
          input.focus();
          input.select();

          input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
              closeModal(input.value);
            }
          });

          card.querySelector('#app-modal-cancel-btn').onclick = () => closeModal(null);
          card.querySelector('#app-modal-ok-btn').onclick = () => closeModal(input.value);
        });
      });
    },

    /**
     * Custom Partial Issue Modal
     */
    partialIssue: function (data) {
      return new Promise((resolve) => {
        const requestedQty = parseFloat(data.requestedQty) || 0;
        const unit = data.unit || 'units';
        const materialName = data.materialName || 'Material';

        const html = `
          <div class="app-modal-header">
            <div class="app-modal-icon-wrap app-modal-icon-orange">⏳</div>
            <div class="app-modal-title-group">
              <h3 class="app-modal-title">Issue Partial Quantity</h3>
              <p class="app-modal-subtitle">${materialName}</p>
            </div>
          </div>
          <div class="app-modal-body">
            <div class="app-modal-badge-info">
              <span>📋 Requested Quantity:</span>
              <strong>${requestedQty} ${unit}</strong>
            </div>

            <div class="app-modal-form-group">
              <label class="app-modal-label">Partial Quantity to Issue *</label>
              <input type="number" step="any" min="0.01" max="${requestedQty - 0.001}" class="app-modal-input app-modal-input-orange" id="partial-qty-input" placeholder="e.g. 5">
              <div class="app-modal-error-text" id="partial-qty-error"></div>
            </div>

            <div class="app-modal-form-group">
              <label class="app-modal-label">Store Note / Remark (Optional)</label>
              <input type="text" class="app-modal-input" id="partial-remark-input" placeholder="e.g. Only 5 available in current stock...">
            </div>
          </div>
          <div class="app-modal-footer">
            <button type="button" class="app-modal-btn app-modal-btn-cancel" id="partial-cancel-btn">Cancel</button>
            <button type="button" class="app-modal-btn app-modal-btn-orange" id="partial-submit-btn">Issue Partial Quantity</button>
          </div>
        `;

        ensureOverlay()._resolver = resolve;
        openModal(html, (card) => {
          const qtyInput = card.querySelector('#partial-qty-input');
          const remarkInput = card.querySelector('#partial-remark-input');
          const errorEl = card.querySelector('#partial-qty-error');
          const submitBtn = card.querySelector('#partial-submit-btn');
          const cancelBtn = card.querySelector('#partial-cancel-btn');

          qtyInput.focus();

          function validateAndSubmit() {
            const val = parseFloat(qtyInput.value);
            if (isNaN(val) || val <= 0) {
              errorEl.textContent = 'Please enter a valid positive quantity.';
              errorEl.style.display = 'block';
              qtyInput.focus();
              return;
            }

            if (val >= requestedQty) {
              errorEl.textContent = `Partial quantity must be less than requested (${requestedQty}). For full quantity, use 'Issue Full'.`;
              errorEl.style.display = 'block';
              qtyInput.focus();
              return;
            }

            errorEl.style.display = 'none';
            closeModal({
              issued_quantity: val,
              remark: remarkInput.value.trim()
            });
          }

          submitBtn.onclick = validateAndSubmit;
          cancelBtn.onclick = () => closeModal(null);

          qtyInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') validateAndSubmit();
          });
          remarkInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') validateAndSubmit();
          });
        });
      });
    },

    /**
     * Custom Not Available Modal
     */
    notAvailable: function (data) {
      return new Promise((resolve) => {
        const materialName = data.materialName || 'Material';

        const html = `
          <div class="app-modal-header">
            <div class="app-modal-icon-wrap app-modal-icon-red">✕</div>
            <div class="app-modal-title-group">
              <h3 class="app-modal-title">Mark as Not Available</h3>
              <p class="app-modal-subtitle">${materialName}</p>
            </div>
          </div>
          <div class="app-modal-body">
            <p style="margin-top:0; color:#475569; font-size:13px; line-height:1.4;">
              Are you sure you want to mark this item as unavailable? The requisition user will see this status in real-time.
            </p>
            <div class="app-modal-form-group">
              <label class="app-modal-label">Reason for Unavailability *</label>
              <input type="text" class="app-modal-input app-modal-input-danger" id="na-remark-input" value="Out of stock in store" placeholder="e.g. Out of stock, Discontinued...">
            </div>
          </div>
          <div class="app-modal-footer">
            <button type="button" class="app-modal-btn app-modal-btn-cancel" id="na-cancel-btn">Cancel</button>
            <button type="button" class="app-modal-btn app-modal-btn-danger" id="na-submit-btn">Mark Not Available</button>
          </div>
        `;

        ensureOverlay()._resolver = resolve;
        openModal(html, (card) => {
          const remarkInput = card.querySelector('#na-remark-input');
          const submitBtn = card.querySelector('#na-submit-btn');
          const cancelBtn = card.querySelector('#na-cancel-btn');

          remarkInput.focus();
          remarkInput.select();

          function submit() {
            closeModal({
              remark: remarkInput.value.trim() || 'Out of stock in store'
            });
          }

          submitBtn.onclick = submit;
          cancelBtn.onclick = () => closeModal(null);
          remarkInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') submit();
          });
        });
      });
    }
  };
})();

// Safety: Overwrite window native dialogs so NO domain header is EVER shown
window.customAlert = AppModal.alert;
window.customConfirm = AppModal.confirm;
window.customPrompt = AppModal.prompt;

// Intercept window.alert so legacy or unexpected alerts use AppModal
window.alert = function (msg) {
  AppModal.alert(msg);
};
