import React from 'react';
import { Menu, MenuItem, ListItemIcon } from '@mui/material';
import { FileDownload as FileDownloadIcon, PictureAsPdf as PdfIcon, TableChart as ExcelIcon } from '@mui/icons-material';
import appConfig from '../../../config';

const colors = appConfig.app.colors;

const ReportExportMenu = ({ anchorEl, open, onClose, onExportCSV, onExportExcel, onExportPDF }) => {
    return (
        <Menu anchorEl={anchorEl} open={open} onClose={onClose}>
            <MenuItem onClick={onExportCSV}>
                <ListItemIcon>
                    <FileDownloadIcon fontSize="small" sx={{ color: colors.sea }} />
                </ListItemIcon>
                CSV
            </MenuItem>
            <MenuItem onClick={onExportExcel}>
                <ListItemIcon>
                    <ExcelIcon fontSize="small" sx={{ color: colors.salat }} />
                </ListItemIcon>
                Excel
            </MenuItem>
            <MenuItem onClick={onExportPDF}>
                <ListItemIcon>
                    <PdfIcon fontSize="small" sx={{ color: 'error.main' }} />
                </ListItemIcon>
                PDF
            </MenuItem>
        </Menu>
    );
};

export default ReportExportMenu;