import React from 'react';
import { Chip } from '@mui/material';
import {
    Pending as PendingIcon,
    CheckCircle as CheckCircleIcon,
    Schedule as ScheduleIcon,
    Cancel as CancelIcon,
} from '@mui/icons-material';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const StatusChip = ({ status }) => {
    const statusMap = {
        pending: { color: 'warning', icon: <PendingIcon sx={{ fontSize: 14 }} />, label: 'Pending' },
        accepted: { color: 'info', icon: <CheckCircleIcon sx={{ fontSize: 14 }} />, label: 'Accepted' },
        in_progress: { color: 'primary', icon: <ScheduleIcon sx={{ fontSize: 14 }} />, label: 'In Progress' },
        completed: { color: 'success', icon: <CheckCircleIcon sx={{ fontSize: 14 }} />, label: 'Completed' },
        cancelled: { color: 'default', icon: <CancelIcon sx={{ fontSize: 14 }} />, label: 'Cancelled' },
        rejected: { color: 'error', icon: <CancelIcon sx={{ fontSize: 14 }} />, label: 'Rejected' },
        active: { color: 'success', icon: <CheckCircleIcon sx={{ fontSize: 14 }} />, label: 'Active' },
        inactive: { color: 'default', icon: <CancelIcon sx={{ fontSize: 14 }} />, label: 'Inactive' },
        pending_verification: { color: 'warning', icon: <PendingIcon sx={{ fontSize: 14 }} />, label: 'Pending Verification' },
    };

    const config = statusMap[status] || statusMap.pending;
    const bgColor =
        config.color === 'warning'
            ? '#fef3c7'
            : config.color === 'success'
                ? '#d1fae5'
                : config.color === 'error'
                    ? '#fee2e2'
                    : config.color === 'info'
                        ? '#dbeafe'
                        : config.color === 'primary'
                            ? '#dbeafe'
                            : colors.sky;

    const textColor =
        config.color === 'warning'
            ? '#92400e'
            : config.color === 'success'
                ? '#065f46'
                : config.color === 'error'
                    ? '#991b1b'
                    : config.color === 'info'
                        ? '#1e40af'
                        : config.color === 'primary'
                            ? '#1e40af'
                            : colors.rain;

    return (
        <Chip
            icon={config.icon}
            label={config.label}
            size="small"
            sx={{ backgroundColor: bgColor, color: textColor, borderColor: colors.middle }}
        />
    );
};

export default StatusChip;