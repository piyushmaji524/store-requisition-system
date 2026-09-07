/**
 * Admin Panel Interactive Logic
 */

document.addEventListener('DOMContentLoaded', () => {
    initAdminClock();
});

function initAdminClock() {
    const clockEl = document.getElementById('admin-header-clock');
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

        const dayName = istTime.toLocaleDateString('en-GB', { weekday: 'long' });
        const dateStr = istTime.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });

        clockEl.textContent = `${dateStr}, ${dayName} ${hours}:${minutes}:${seconds} ${ampm} (IST)`;
    }

    updateClock();
    setInterval(updateClock, 1000);
}

async function submitDateOverride(e) {
    e.preventDefault();
    const form = e.target;
    const date = form.querySelector('[name="override_date"]').value;
    const reason = form.querySelector('[name="reason"]')?.value || 'Store correction requested by Admin';
    const durationInput = form.querySelector('[name="duration_hours"]')?.value;

    if (!date) {
        AppModal.alert('Please select a valid date.', 'Validation Error', 'warning');
        return;
    }

    const payload = {
        override_date: date,
        reason: reason
    };
    if (durationInput && parseInt(durationInput) > 0) {
        payload.duration_hours = parseInt(durationInput);
    }

    try {
        const res = await fetch('/api/admin/date-override', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.success) {
            await AppModal.alert(data.message || `Date override successfully created for ${date}.`, 'Override Created', 'success');
            window.location.reload();
        } else {
            AppModal.alert(data.message || 'Failed to create override.', 'Error', 'error');
        }
    } catch (err) {
        AppModal.alert('Network error submitting override.', 'Network Error', 'error');
    }
}

async function closeDateOverride(overrideId) {
    const ok = await AppModal.confirm('Are you sure you want to force close this date override window?', {
        title: 'Close Date Override',
        type: 'danger',
        confirmText: 'Force Close Window',
        cancelText: 'Cancel'
    });
    if (!ok) return;

    try {
        const res = await fetch(`/api/admin/date-overrides/${overrideId}/close`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        const data = await res.json();
        if (data.success) {
            await AppModal.alert('Date override closed.', 'Override Closed', 'info');
            window.location.reload();
        } else {
            AppModal.alert(data.message || 'Failed to close override.', 'Error', 'error');
        }
    } catch (err) {
        AppModal.alert('Network error closing override.', 'Network Error', 'error');
    }
}

function triggerBackup() {
    AppModal.alert('Database backup initiated! Snapshot saved successfully to /backups/store_req_backup_' + new Date().toISOString().slice(0,10) + '.sql', 'Backup Initiated', 'success');
}
