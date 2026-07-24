////////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2026 Ripose
//
// This file is part of Memento.
//
// Memento is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 2 of the License.
//
// Memento is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Memento.  If not, see <https://www.gnu.org/licenses/>.
//
////////////////////////////////////////////////////////////////////////////////

#pragma once

#include <QObject>
#include <QQuickImageProvider>

#include <memory>

#include <QImage>
#include <QMutex>
#include <QRectF>

#ifdef MEMENTO_SYSTEM_QCORO
#include <QCoroQmlTask>
#include <QCoroTask>
#else
#include <qcoro/qml/qcoroqmltask.h>
#include <qcoro/qcorotask.h>
#endif // MEMENTO_SYSTEM_QCORO

class MpvController;
class QQuickItem;
class Settings;

#ifdef MEMENTO_OCR_SUPPORT
class OcrModel;
#endif // MEMENTO_OCR_SUPPORT

/**
 * @brief QML interface for OCRing a selected player region.
 */
class OcrController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(
        QString heldFrameUrl
        READ heldFrameUrl
        NOTIFY heldFrameChanged
    )

public:
    /**
     * @brief Create an OcrController.
     *
     * @param settings The application settings object.
     * @param parent The parent object.
     */
    explicit OcrController(Settings *settings, QObject *parent = nullptr);
    virtual ~OcrController();

    /**
     * @brief OCR a selected rectangle in player coordinates.
     *
     * @param controller The controller for the player to capture.
     * @param selection The selected region in player coordinates.
     * @param playerWidth The width of the player item.
     * @param playerHeight The height of the player item.
     * @return A map with "text" on success or "error" on failure.
     */
    Q_INVOKABLE QCoro::QmlTask readRegion(
        MpvController *controller,
        const QRectF &selection,
        double playerWidth,
        double playerHeight);

    /**
     * @brief Capture and hold the player as displayed on screen. Grabs the
     * composed window (video, mpv subtitles and QML-rendered subtitles) and
     * crops it to the player item, so the held frame is exactly what the
     * user sees — an mpv re-render at a subtitle end boundary can drop the
     * line. Held frames are displayed over the player and OCRed in place of
     * a live screenshot, so playback changes cannot invalidate an
     * in-progress selection. If a frame is already held, it is kept as is.
     *
     * @param player The player item to capture.
     * @return True if a frame is held after the call.
     */
    Q_INVOKABLE bool holdFrame(QQuickItem *player);

    /**
     * @brief Release the held video frame.
     */
    Q_INVOKABLE void releaseFrame();

    /**
     * @brief Begin loading the OCR model if it is not already loaded.
     */
    Q_INVOKABLE void warmup();

    /**
     * @brief Get the image provider URL for the held frame.
     *
     * @return The URL, or the empty string if no frame is held.
     */
    [[nodiscard]]
    QString heldFrameUrl() const;

    /**
     * @brief Get a copy of the held frame.
     *
     * @return The held frame. Null if no frame is held.
     */
    [[nodiscard]]
    QImage heldFrame() const;

signals:
    /**
     * @brief Emitted when a frame is held or released.
     */
    void heldFrameChanged();

private:
    /**
     * @brief Async implementation for readRegion.
     *
     * @param controller The controller for the player to capture.
     * @param selection The selected region in player coordinates.
     * @param playerWidth The width of the player item.
     * @param playerHeight The height of the player item.
     * @return An awaitable task with map with "text" on success or "error" on
     * failure.
     */
    QCoro::Task<QVariantMap> readRegionAsync(
        MpvController *controller,
        QRectF selection,
        double playerWidth,
        double playerHeight);

#ifdef MEMENTO_OCR_SUPPORT
    /**
     * @brief Get the loaded OCR model, recreating it if settings changed.
     */
    OcrModel *model();

    /**
     * @brief Set HF_HUB_OFFLINE=1 if the configured model is already in the
     * local Hugging Face cache, so model loads never touch the network.
     * Respects offline variables the user has already set. Called once at
     * startup; transformers reads the variable at import time.
     */
    void setOfflineModeIfCached() const;
#endif // MEMENTO_OCR_SUPPORT

    /* Application settings */
    Settings *m_settings{nullptr};

    /* The held video frame OCR selections are read from */
    QImage m_heldFrame;

    /* Guards m_heldFrame against the image provider thread */
    mutable QMutex m_heldFrameLock;

    /* Incremented per held frame so QML never shows a cached image */
    quint64 m_heldFrameId{0};

#ifdef MEMENTO_OCR_SUPPORT
    /* Lazily loaded OCR model */
    std::unique_ptr<OcrModel> m_model;

    /* Name of the manga_ocr HF model to use */
    QString m_modelName;

    /* true to use the GPU when doing OCR, false otherwise */
    bool m_useGpu{false};
#endif // MEMENTO_OCR_SUPPORT
};

/**
 * @brief Image provider exposing the held OCR frame to QML.
 */
class OcrFrameImageProvider : public QQuickImageProvider
{
public:
    /**
     * @brief Create an OcrFrameImageProvider.
     *
     * @param controller The controller holding the frame.
     */
    explicit OcrFrameImageProvider(OcrController *controller);

    QImage requestImage(
        const QString &id,
        QSize *size,
        const QSize &requestedSize) override;

private:
    /* The controller holding the frame */
    OcrController *m_controller{nullptr};
};
