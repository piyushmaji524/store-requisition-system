/**
 * Store Panel Interactive Client
 * Real-time fulfillments, user tabs, emergency modals, and toast alerts
 */

document.addEventListener('DOMContentLoaded', () => {
    initRealTimeClock();
    initModals();
    initCopyRequisitionNo();
    initSearchFilter();
    initAutoSyncPoller();
});

/**
 * Real-time IST Clock in header
 */
function initRealTimeClock() {
    const clockEl = document.getElementById('header-clock');
    if (!clockEl) return;

    function updateClock() {
        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const istTime = new Date(now.getTime() + (now.getTimezoneOffset() * 60000) + istOffset);
        
        let hours = istTime.getHours();
        const minutes = String(istTime.getMinutes()).padStart(2, '0');
        const seconds = String(istTime.getSeconds()).padStart(2, '0');
        const ampm = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12 || 12;

        const options = { day: 'numeric', month: 'short', year: 'numeric' };
        const dateStr = istTime.toLocaleDateString('en-GB', options);

        clockEl.textContent = `Current Time: ${hours}:${minutes}:${seconds} ${ampm}, ${dateStr}`;
    }

    updateClock();
    setInterval(updateClock, 1000);
}

/**
 * Toast Notifications
 */
function showToast(message, isError = false) {
    let toast = document.getElementById('app-toast');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'app-toast';
        toast.className = 'toast';
        document.body.appendChild(toast);
    }
    toast.style.backgroundColor = isError ? '#ef4444' : '#0f172a';
    toast.textContent = message;
    toast.classList.add('show');

    setTimeout(() => {
        toast.classList.remove('show');
    }, 3500);
}

/**
 * Copy Requisition Number to Clipboard
 */
function initCopyRequisitionNo() {
    const copyBtn = document.getElementById('copy-req-no');
    if (!copyBtn) return;

    copyBtn.addEventListener('click', () => {
        const text = copyBtn.getAttribute('data-req-no');
        if (text) {
            navigator.clipboard.writeText(text).then(() => {
                showToast(`Copied ${text} to clipboard!`);
            });
        }
    });
}

/**
 * Fast Client-Side Search Filter
 */
function initSearchFilter() {
    const searchInput = document.getElementById('table-search-input');
    if (!searchInput) return;

    searchInput.addEventListener('input', (e) => {
        const q = e.target.value.toLowerCase().trim();
        const rows = document.querySelectorAll('.item-row');
        
        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            if (!q || text.includes(q)) {
                row.style.display = '';
            } else {
                row.style.display = 'none';
            }
        });
    });
}

/**
 * Quick Filter Tabs by Status (All, Pending, Issued, etc.)
 */
let currentActiveStatusFilter = 'ALL';

function filterByStatus(status, btnElement) {
    currentActiveStatusFilter = status;
    
    // Update active state on tab buttons
    document.querySelectorAll('.filter-tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    if (btnElement) {
        btnElement.classList.add('active');
    }

    const rows = document.querySelectorAll('.item-row');
    let visibleCount = 0;

    rows.forEach(row => {
        const rowStatus = (row.getAttribute('data-item-status') || '').toUpperCase();
        if (status === 'ALL' || rowStatus === status) {
            row.style.display = '';
            visibleCount++;
        } else {
            row.style.display = 'none';
        }
    });

    // Check empty sub-requisition cards
    document.querySelectorAll('.sub-requisition-card').forEach(card => {
        const cardRows = card.querySelectorAll('.item-row');
        let cardHasVisible = false;
        cardRows.forEach(r => {
            if (r.style.display !== 'none') cardHasVisible = true;
        });
        const emptyMsg = card.querySelector('.sub-empty-filter-notice');
        if (emptyMsg) {
            emptyMsg.style.display = cardHasVisible ? 'none' : 'block';
        }
    });
}

/**
 * Modal Management
 */
function initModals() {
    document.querySelectorAll('.modal-backdrop').forEach(backdrop => {
        backdrop.addEventListener('click', (e) => {
            if (e.target === backdrop) {
                backdrop.classList.remove('show');
            }
        });
    });

    document.querySelectorAll('.modal-close-btn, .btn-modal-cancel').forEach(btn => {
        btn.addEventListener('click', () => {
            const modal = btn.closest('.modal-backdrop');
            if (modal) modal.classList.remove('show');
        });
    });
}

function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.add('show');
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.classList.remove('show');
}

/**
 * Process Full Issue on an Item
 */
async function issueFullQty(itemId, requestedQty) {
    const row = document.querySelector(`.item-row[data-item-id="${itemId}"]`);
    const matName = row ? (row.querySelector('.material-info strong')?.textContent?.trim() || 'this item') : 'this item';

    const confirmed = await AppModal.confirm(
        `Are you sure you want to issue full quantity (${requestedQty}) for "${matName}"?`,
        {
            title: 'Confirm Full Issue',
            type: 'green',
            confirmText: 'Issue Full Quantity',
            cancelText: 'Cancel'
        }
    );
    if (!confirmed) return;

    try {
        const response = await fetch(`/api/store/items/${itemId}/issue`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });

        const res = await response.json();
        if (res.success) {
            showToast('Material issued successfully!');
            setTimeout(() => window.location.reload(), 500);
        } else {
            showToast(res.message || 'Action failed.', true);
        }
    } catch (err) {
        showToast('Network error processing request.', true);
    }
}

/**
 * Process Partial Issue
 */
async function issuePartialQty(itemId, requestedQty) {
    const row = document.querySelector(`.item-row[data-item-id="${itemId}"]`);
    const matName = row ? (row.querySelector('.material-info strong')?.textContent?.trim() || 'Material') : 'Material';
    const unit = row ? (row.querySelector('.col-unit')?.textContent?.trim() || '') : '';

    const data = await AppModal.partialIssue({
        materialName: matName,
        requestedQty: requestedQty,
        unit: unit
    });

    if (!data) return;
    const qty = data.issued_quantity;
    const remark = data.remark;

    try {
        const response = await fetch(`/api/store/items/${itemId}/partial`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ issued_quantity: qty, remark: remark })
        });

        const res = await response.json();
        if (res.success) {
            showToast(`Partially issued ${qty}!`);
            setTimeout(() => window.location.reload(), 500);
        } else {
            showToast(res.message || 'Action failed.', true);
        }
    } catch (err) {
        showToast('Network error processing request.', true);
    }
}

/**
 * Mark Item as Not Available
 */
async function markNotAvailable(itemId) {
    const row = document.querySelector(`.item-row[data-item-id="${itemId}"]`);
    const matName = row ? (row.querySelector('.material-info strong')?.textContent?.trim() || 'Material') : 'Material';

    const data = await AppModal.notAvailable({
        materialName: matName
    });

    if (!data) return;
    const remark = data.remark;

    try {
        const response = await fetch(`/api/store/items/${itemId}/not-available`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ remark: remark })
        });

        const res = await response.json();
        if (res.success) {
            showToast('Item marked as Not Available.');
            setTimeout(() => window.location.reload(), 500);
        } else {
            showToast(res.message || 'Action failed.', true);
        }
    } catch (err) {
        showToast('Network error processing request.', true);
    }
}

/**
 * Quick Issue ALL Pending Items in a Sub-Requisition
 */
async function issueAllPendingInSub(subRequisitionId) {
    const pendingRows = document.querySelectorAll(`[data-sub-id="${subRequisitionId}"] .item-row[data-item-status="PENDING"]`);
    if (pendingRows.length === 0) {
        AppModal.alert('No pending items in this location.', 'Information', 'info');
        return;
    }

    const confirmed = await AppModal.confirm(
        `Are you sure you want to Full Issue all ${pendingRows.length} pending items in this location at once?`,
        {
            title: 'Quick Issue All Pending',
            type: 'green',
            confirmText: `Issue All ${pendingRows.length} Items`,
            cancelText: 'Cancel'
        }
    );
    if (!confirmed) return;

    let successCount = 0;
    showToast(`Issuing ${pendingRows.length} items...`);

    for (const row of pendingRows) {
        const itemId = row.getAttribute('data-item-id');
        try {
            const res = await fetch(`/api/store/items/${itemId}/issue`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
            const data = await res.json();
            if (data.success) successCount++;
        } catch (e) {
            console.error(e);
        }
    }

    showToast(`Successfully issued ${successCount} items!`);
    setTimeout(() => window.location.reload(), 700);
}

/**
 * Save Inline Table Issued Quantities
 */
async function saveLocationChanges(subRequisitionId) {
    const rows = document.querySelectorAll(`[data-sub-id="${subRequisitionId}"] .item-row`);
    let processed = 0;

    for (const row of rows) {
        const itemId = row.getAttribute('data-item-id');
        const reqQty = parseFloat(row.getAttribute('data-req-qty'));
        const input = row.querySelector('.qty-input-box');
        if (!input) continue;

        const currentIssued = parseFloat(input.value) || 0;
        const originalIssued = parseFloat(row.getAttribute('data-orig-issued')) || 0;

        if (currentIssued !== originalIssued) {
            let action = 'PARTIAL_ISSUE';
            if (currentIssued >= reqQty) {
                action = 'FULL_ISSUE';
            } else if (currentIssued === 0) {
                action = 'NOT_AVAILABLE';
            }

            const url = action === 'FULL_ISSUE' 
                ? `/api/store/items/${itemId}/issue` 
                : (action === 'NOT_AVAILABLE' ? `/api/store/items/${itemId}/not-available` : `/api/store/items/${itemId}/partial`);

            const payload = action === 'PARTIAL_ISSUE' ? { issued_quantity: currentIssued } : {};

            try {
                await fetch(url, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                processed++;
            } catch (e) {
                console.error(e);
            }
        }
    }

    if (processed > 0) {
        showToast(`Saved changes for ${processed} item(s)!`);
        setTimeout(() => window.location.reload(), 600);
    } else {
        showToast('No quantity changes detected.');
    }
}

/**
 * Handle Emergency Issue Form Submission
 */
async function submitEmergencyIssue(e) {
    e.preventDefault();
    const form = e.target;
    const formData = new FormData(form);

    const payload = {
        user_id: parseInt(formData.get('user_id')),
        material_id: parseInt(formData.get('material_id')),
        quantity: parseFloat(formData.get('quantity')),
        location_id: parseInt(formData.get('location_id')),
        reason: formData.get('reason'),
        remark: formData.get('remark')
    };

    if (!payload.user_id || !payload.material_id || !payload.quantity || !payload.location_id || !payload.reason) {
        AppModal.alert('Please fill all mandatory fields including reason.', 'Incomplete Form', 'warning');
        return;
    }

    try {
        const response = await fetch('/api/store/emergency', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const res = await response.json();
        if (res.success) {
            showToast('Emergency material issued and linked to requisition!');
            closeModal('emergency-modal');
            form.reset();
            setTimeout(() => window.location.reload(), 800);
        } else {
            showToast(res.message || 'Emergency issue failed.', true);
        }
    } catch (err) {
        showToast('Network error processing emergency request.', true);
    }
}

/**
 * Real-time Background Auto-Sync for Store Panel
 * Polls for updates every 8 seconds when user is not typing in inputs or interacting with modals
 */
function initAutoSyncPoller() {
    let lastCheckTime = Date.now();

    setInterval(async () => {
        // Do not auto-refresh if user is actively typing in input/textarea or modal is open
        const activeTag = document.activeElement ? document.activeElement.tagName : '';
        const isTyping = (activeTag === 'INPUT' || activeTag === 'TEXTAREA' || activeTag === 'SELECT');
        const modalOpen = document.querySelector('.modal-backdrop.show');

        if (isTyping || modalOpen) return;

        try {
            // Fetch live current state from server
            const res = await fetch(window.location.href, {
                headers: { 'X-Requested-With': 'XMLHttpRequest' }
            });
            if (res.ok) {
                const text = await res.text();
                const parser = new DOMParser();
                const newDoc = parser.parseFromString(text, 'text/html');

                // Check if user pills, tables, or pending counts have updated
                const oldWorkspace = document.querySelector('.main-wrapper');
                const newWorkspace = newDoc.querySelector('.main-wrapper');

                if (oldWorkspace && newWorkspace && oldWorkspace.innerHTML !== newWorkspace.innerHTML) {
                    // Seamlessly replace main workspace preserving active filter
                    oldWorkspace.innerHTML = newWorkspace.innerHTML;
                    initCopyRequisitionNo();
                    initSearchFilter();
                    if (typeof currentActiveStatusFilter !== 'undefined' && currentActiveStatusFilter !== 'ALL') {
                        filterByStatus(currentActiveStatusFilter);
                    }
                }
            }
        } catch (e) {
            // Fail silently on network interruptions
        }
    }, 8000);
}
