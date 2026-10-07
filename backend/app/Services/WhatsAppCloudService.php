<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;

/**
 * Sends a customer's invoice image (PNG) through the WhatsApp Business Cloud API.
 *
 * Inside the 24h customer-service window a plain image message is enough.
 * Outside it WhatsApp only accepts an approved template, so when
 * WHATSAPP_INVOICE_TEMPLATE is set the image is sent as that template's IMAGE
 * header (body variables: {{1}} order number, {{2}} branch name).
 */
final class WhatsAppCloudService
{
    public function isConfigured(): bool
    {
        return filled(config('services.whatsapp.token')) && filled(config('services.whatsapp.phone_number_id'));
    }

    /** Digits-only international number (no "+"), or null when it cannot be one. */
    public static function normalizePhone(string $raw): ?string
    {
        $digits = strtr(trim($raw), [
            '٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4',
            '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9',
            '۰' => '0', '۱' => '1', '۲' => '2', '۳' => '3', '۴' => '4',
            '۵' => '5', '۶' => '6', '۷' => '7', '۸' => '8', '۹' => '9',
        ]);
        $hasPlus = str_starts_with($digits, '+');
        $digits = preg_replace('/\D/', '', $digits) ?? '';
        if ($digits === '') {
            return null;
        }
        if (! $hasPlus && str_starts_with($digits, '00')) {
            $digits = substr($digits, 2);
        } elseif (! $hasPlus && str_starts_with($digits, '0')) {
            $digits = (string) config('services.whatsapp.default_country_code', '963').ltrim($digits, '0');
        }

        return strlen($digits) >= 8 && strlen($digits) <= 15 ? $digits : null;
    }

    /** @return string WhatsApp message id */
    public function sendInvoiceImage(string $to, UploadedFile $image, string $filename, string $orderNumber, string $branchName): string
    {
        $mediaId = $this->uploadImage($image, $filename);
        $template = config('services.whatsapp.template');

        $message = $template
            ? [
                'type' => 'template',
                'template' => [
                    'name' => $template,
                    'language' => ['code' => config('services.whatsapp.template_language', 'ar')],
                    'components' => [
                        ['type' => 'header', 'parameters' => [['type' => 'image', 'image' => ['id' => $mediaId]]]],
                        ['type' => 'body', 'parameters' => [['type' => 'text', 'text' => $orderNumber], ['type' => 'text', 'text' => $branchName]]],
                    ],
                ],
            ]
            : [
                'type' => 'image',
                'image' => ['id' => $mediaId, 'caption' => $branchName.' - '.$orderNumber],
            ];

        $response = $this->request('messages', fn ($http) => $http->asJson()->post($this->url('messages'), ['messaging_product' => 'whatsapp', 'to' => $to] + $message));

        $id = $response->json('messages.0.id');
        if (! is_string($id) || $id === '') {
            throw new WhatsAppDeliveryException('WhatsApp did not confirm the message.');
        }

        return $id;
    }

    private function uploadImage(UploadedFile $image, string $filename): string
    {
        $response = $this->request('media', fn ($http) => $http
            ->attach('file', (string) file_get_contents($image->getRealPath()), $filename, ['Content-Type' => 'image/png'])
            ->post($this->url('media'), ['messaging_product' => 'whatsapp', 'type' => 'image/png']));

        $id = $response->json('id');
        if (! is_string($id) || $id === '') {
            throw new WhatsAppDeliveryException('WhatsApp rejected the invoice image.');
        }

        return $id;
    }

    private function request(string $what, callable $send): Response
    {
        try {
            $response = $send(Http::withToken((string) config('services.whatsapp.token'))->timeout(30));
        } catch (ConnectionException) {
            throw new WhatsAppDeliveryException('Could not reach WhatsApp.', 'whatsapp_unreachable');
        }
        if ($response->failed()) {
            // Meta's error text is safe to surface; never include the token or request body.
            $detail = (string) $response->json('error.message', 'HTTP '.$response->status());
            throw new WhatsAppDeliveryException("WhatsApp {$what} request failed: {$detail}");
        }

        return $response;
    }

    private function url(string $path): string
    {
        return sprintf('https://graph.facebook.com/%s/%s/%s', config('services.whatsapp.api_version', 'v21.0'), config('services.whatsapp.phone_number_id'), $path);
    }
}
